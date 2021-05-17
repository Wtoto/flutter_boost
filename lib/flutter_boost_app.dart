import 'dart:async';
import 'package:flutter_boost/boost_container.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_boost/messages.dart';
import 'package:flutter_boost/boost_flutter_router_api.dart';
import 'package:flutter_boost/logger.dart';
import 'package:flutter_boost/boost_navigator.dart';
import 'package:flutter_boost/page_visibility.dart';
import 'package:flutter_boost/overlay_entry.dart';

typedef FlutterBoostAppBuilder = Widget Function(Widget home);
typedef FlutterBoostRouteFactory = Route<dynamic> Function(
    RouteSettings settings, String uniqueId);

typedef PageBuilder = Widget Function(
    BuildContext context, RouteSettings settings);

class FlutterBoostApp extends StatefulWidget {
  const FlutterBoostApp(this.routeFactory,
      {FlutterBoostAppBuilder? appBuilder, String? initialRoute})
      : appBuilder = appBuilder ?? _materialAppBuilder,
        initialRoute = initialRoute ?? '/';

  final FlutterBoostRouteFactory routeFactory;
  final FlutterBoostAppBuilder appBuilder;
  final String initialRoute;

  static Widget _materialAppBuilder(Widget home) {
    return MaterialApp(home: home);
  }

  @override
  State<StatefulWidget> createState() => FlutterBoostAppState();
}

class FlutterBoostAppState extends State<FlutterBoostApp> {
  final Map<String, Completer<Object>> _pendingResult =
      <String, Completer<Object>>{};

  List<BoostContainer> get containers => _containers;
  final List<BoostContainer> _containers = <BoostContainer>[];

  BoostContainer get topContainer => containers.last;

  NativeRouterApi get nativeRouterApi => _nativeRouterApi;
  late NativeRouterApi _nativeRouterApi;

  BoostFlutterRouterApi get boostFlutterRouterApi => _boostFlutterRouterApi;
  late BoostFlutterRouterApi _boostFlutterRouterApi;

  FlutterBoostRouteFactory get routeFactory => widget.routeFactory;
  final Set<int> _activePointers = <int>{};

  @override
  void initState() {
    final pageName = widget.initialRoute;
    _containers.add(_createContainer(
        PageInfo(pageName: pageName, uniqueId: _createUniqueId(pageName))));
    _nativeRouterApi = NativeRouterApi();
    _boostFlutterRouterApi = BoostFlutterRouterApi(this);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return widget.appBuilder(WillPopScope(
        onWillPop: () async {
          final bool? canPop = topContainer.navigator?.canPop();
          if (canPop != null && canPop) {
            topContainer.navigator?.pop();
            return true;
          }
          return false;
        },
        child: Listener(
            onPointerDown: _handlePointerDown,
            onPointerUp: _handlePointerUpOrCancel,
            onPointerCancel: _handlePointerUpOrCancel,
            child: Overlay(
              key: overlayKey,
              initialEntries: _initialEntries(),
            ))));
  }

  List<OverlayEntry> _initialEntries() {
    final List<OverlayEntry> entries = <OverlayEntry>[];
    final OverlayState? overlayState = overlayKey.currentState;
    if (overlayState == null) {
      for (BoostContainer container in containers) {
        final ContainerOverlayEntry entry = ContainerOverlayEntry(container);
        entries.add(entry);
      }
    }
    return entries;
  }

  void _handlePointerDown(PointerDownEvent event) {
    _activePointers.add(event.pointer);
  }

  void _handlePointerUpOrCancel(PointerEvent event) {
    _activePointers.remove(event.pointer);
  }

  void _cancelActivePointers() {
    final instance = WidgetsBinding.instance;
    if (instance != null) {
      _activePointers.toList().forEach(instance.cancelPointer);
    }
  }

  String _createUniqueId(String pageName) {
    if (kReleaseMode) {
      return Uuid().v4();
    } else {
      return Uuid().v4() + '#$pageName';
    }
  }

  BoostContainer _createContainer(PageInfo pageInfo) {
    //pageInfo.uniqueId ??= _createUniqueId(pageInfo.pageName);
    return BoostContainer(
        key: ValueKey<String>(pageInfo.uniqueId),
        pageInfo: pageInfo,
        routeFactory: widget.routeFactory);
  }

  Future<T> pushWithResult<T extends Object>(String pageName,
      {Map<Object, Object>? arguments, bool withContainer = true}) {
    final Completer<T> completer = Completer<T>();

    String uniqueId = _createUniqueId(pageName);
    if (withContainer) {
      final CommonParams params = CommonParams()
        ..pageName = pageName
        ..uniqueId = uniqueId
        ..arguments = arguments;
      nativeRouterApi.pushFlutterRoute(params);
    } else {
      push(pageName,
          uniqueId: uniqueId, arguments: arguments, withContainer: false);
    }
    _pendingResult[uniqueId] = completer;
    return completer.future;
  }

  void push(String pageName,
      {required String uniqueId,
      Map<dynamic, dynamic>? arguments,
      bool withContainer = true}) {
    _cancelActivePointers();
    final BoostContainer? existed = _findContainerByUniqueId(uniqueId);
    if (existed != null) {
      if (topContainer.pageInfo.uniqueId != uniqueId) {
        containers.remove(existed);
        existed.detach();
        containers.add(existed);
        insertEntry(existed);
        PageVisibilityBinding.instance
            .dispatchPageShowEvent(_getCurrentPageRoute());
        final prevousPageRoute = _getPreviousPageRoute();
        if (prevousPageRoute != null) {
          PageVisibilityBinding.instance
              .dispatchPageHideEvent(prevousPageRoute);
        }
      } else {
        PageVisibilityBinding.instance
            .dispatchPageShowEvent(_getCurrentPageRoute());
      }
    } else {
      final PageInfo pageInfo = PageInfo(
          pageName: pageName,
          uniqueId: uniqueId,
          arguments: arguments,
          withContainer: withContainer);
      if (withContainer) {
        final container = _createContainer(pageInfo);
        containers.add(container);
        insertEntry(container);

        // The observer can't receive the 'pageshow' message indeed，
        // because the observer is not yet registed at the moment.
        //
        // See PageVisibilityBinding#addObserver for the solution.
        PageVisibilityBinding.instance
            .dispatchPageShowEvent(_getCurrentPageRoute());
        final previousPageRoute = _getPreviousPageRoute();
        if (previousPageRoute != null) {
          PageVisibilityBinding.instance
              .dispatchPageHideEvent(previousPageRoute);
        }
      } else {
        final page = BoostPage.create(pageInfo, topContainer.routeFactory);
        topContainer.push(page);
      }
    }
    Logger.log(
        'push page, uniqueId=$uniqueId, existed=$existed, withContainer=$withContainer, arguments:$arguments, $containers');
  }

  void popWithResult<T extends Object>(T? result) {
    final String uniqueId = topContainer.topPage.pageInfo.uniqueId;
    if (_pendingResult.containsKey(uniqueId)) {
      _pendingResult[uniqueId]?.complete(result);
    }
    pop(uniqueId: uniqueId);
  }

  Future<void> pop({String? uniqueId, Map<dynamic, dynamic>? arguments}) async {
    late BoostContainer? container;
    if (uniqueId != null) {
      container = _findContainerByUniqueId(uniqueId);
      if (container == null) {
        Logger.error('uniqueId=$uniqueId not find');
        return;
      }
    } else {
      container = topContainer;
    }

    if (container != topContainer) {
      _removeContainer(container);
      return;
    }

    if (container.pages.length > 1) {
      container.pop();
    } else {
      final bool? handled = await container.navigator?.maybePop();
      if (handled != null && !handled) {
        _removeContainer(container);
      }
    }

    _pendingResult.remove(uniqueId);

    Logger.log(
        'pop container, uniqueId=$uniqueId, arguments:$arguments, $container');
  }

  void _removeContainer(BoostContainer container) async {
    containers.remove(container);

    final route = container.pages.first.route;
    if (route != null) {
      PageVisibilityBinding.instance.dispatchPageDestoryEvent(route);
    }

    if (container.pageInfo.withContainer) {
      Logger.log('_removeContainer ,  uniqueId=${container.pageInfo.uniqueId}');
      final CommonParams params = CommonParams()
        ..pageName = container.pageInfo.pageName
        ..uniqueId = container.pageInfo.uniqueId
        ..arguments = container.pageInfo.arguments;
      await _nativeRouterApi.popRoute(params);
    }
    container.detach();
  }

  void onForeground() {
    PageVisibilityBinding.instance
        .dispatchForegroundEvent(_getCurrentPageRoute());
  }

  void onBackground() {
    PageVisibilityBinding.instance
        .dispatchBackgroundEvent(_getCurrentPageRoute());
  }

  void onNativeViewShow() {
    PageVisibilityBinding.instance
        .dispatchPageHideEvent(_getCurrentPageRoute());
  }

  void onNativeViewHide() {
    PageVisibilityBinding.instance
        .dispatchPageShowEvent(_getCurrentPageRoute());
  }

  Route<dynamic>? _getCurrentPageRoute() {
    return topContainer.topPage.route;
  }

  String _getCurrentPageUniqueId() {
    return topContainer.topPage.pageInfo.uniqueId;
  }

  String? _getPreviousPageUniqueId() {
    assert(topContainer.pages != null);
    final int pageCount = topContainer.pages.length;
    if (pageCount > 1) {
      return topContainer.pages[pageCount - 2].pageInfo.uniqueId;
    } else {
      final int containerCount = containers.length;
      if (containerCount > 1) {
        return containers[containerCount - 2].pages.last.pageInfo.uniqueId;
      }
    }

    return null;
  }

  Route<dynamic>? _getPreviousPageRoute() {
    final int pageCount = topContainer.pages.length;
    if (pageCount > 1) {
      return topContainer.pages[pageCount - 2].route;
    } else {
      final int containerCount = containers.length;
      if (containerCount > 1) {
        return containers[containerCount - 2].pages.last.route;
      }
    }

    return null;
  }

  BoostContainer? _findContainerByUniqueId(String uniqueId) {
    try {
      return containers.singleWhere(
          (BoostContainer element) => element.pageInfo.uniqueId == uniqueId);
    } catch (e) {
      Logger.logObject(e);
    }
    return null;
  }

  void remove(String uniqueId) {
    if (uniqueId == null) {
      return;
    }

    final BoostContainer? container = _findContainerByUniqueId(uniqueId);
    late Route<dynamic>? _route;
    if (container != null) {
      // Gets the first internal route of the current container
      _route = container.pages.first.route;
      containers.removeWhere(
          (BoostContainer entry) => entry.pageInfo.uniqueId == uniqueId);
      //refresh();
    } else {
      for (BoostContainer container in containers) {
        final BoostPage<dynamic> _target = container.pages.firstWhere(
            (BoostPage<dynamic> entry) => entry.pageInfo.uniqueId == uniqueId);
        _route = _target.route;
        container.pages.removeWhere(
            (BoostPage<dynamic> entry) => entry.pageInfo.uniqueId == uniqueId);
      }
      //refresh();
    }
    PageVisibilityBinding.instance.dispatchPageDestoryEvent(_route);
    Logger.log('remove,  uniqueId=$uniqueId, $containers');
  }

  PageInfo getTopPageInfo() {
    return topContainer.topPage.pageInfo;
  }

  int pageSize() {
    int count = 0;
    for (BoostContainer container in containers) {
      count += container.size;
    }
    return count;
  }
}

class BoostPage<T> extends Page<T> {
  BoostPage({LocalKey? key, required this.routeFactory, required this.pageInfo})
      : super(key: key, name: pageInfo.pageName, arguments: pageInfo.arguments);

  final FlutterBoostRouteFactory routeFactory;
  final PageInfo pageInfo;

  static BoostPage<dynamic> create(
      PageInfo pageInfo, FlutterBoostRouteFactory routeFactory) {
    return BoostPage<dynamic>(
        key: UniqueKey(), pageInfo: pageInfo, routeFactory: routeFactory);
  }

  final List<Route<T>> _route = <Route<T>>[];
  Route<T>? get route => _route.isEmpty ? null : _route.first;

  @override
  String toString() =>
      '${objectRuntimeType(this, 'BoostPage')}(name:$name, uniqueId:${pageInfo.uniqueId}, arguments:$arguments)';

  @override
  Route<T> createRoute(BuildContext context) {
    _route.clear();
    _route.add(routeFactory(this, pageInfo.uniqueId) as Route<T>);
    return _route.first;
  }
}

class BoostNavigatorObserver extends NavigatorObserver {
  BoostNavigatorObserver();

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    //handle internal route
    PageVisibilityBinding.instance.dispatchPageShowEvent(route);
    PageVisibilityBinding.instance.dispatchPageHideEvent(previousRoute);
    super.didPush(route, previousRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (previousRoute != null) {
      PageVisibilityBinding.instance.dispatchPageHideEvent(route);
      PageVisibilityBinding.instance.dispatchPageShowEvent(previousRoute);
    }
    super.didPop(route, previousRoute);
  }
}
