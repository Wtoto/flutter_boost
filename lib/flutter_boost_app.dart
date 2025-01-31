import 'dart:async';
import 'dart:io';
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

  final List<BoostContainer> _pendingPopcontainers = <BoostContainer>[];

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
    return BoostContainer(
        key: ValueKey<String>(pageInfo.uniqueId),
        pageInfo: pageInfo,
        routeFactory: widget.routeFactory);
  }

  Future<T> pushWithResult<T extends Object>(String pageName,
      {Map<Object, Object>? arguments, bool withContainer = true}) {
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

    final Completer<T> completer = Completer<T>();
    _pendingResult[uniqueId] = completer;
    return completer.future;
  }

  void push(String pageName,
      {required String uniqueId,
      Map<dynamic, dynamic>? arguments,
      bool withContainer = true}) {
    _cancelActivePointers();
    final BoostContainer? container = _findContainerByUniqueId(uniqueId);
    if (container != null) {
      if (topContainer != container) {
        PageVisibilityBinding.instance
            .dispatchPageHideEvent(_getCurrentPageRoute());
        containers.remove(container);
        container.detach();
        containers.add(container);
        insertEntry(container);
        PageVisibilityBinding.instance
            .dispatchPageShowEvent(container.topPage.route);
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
        PageVisibilityBinding.instance
            .dispatchPageHideEvent(_getCurrentPageRoute());

        final container = _createContainer(pageInfo);
        containers.add(container);
        insertEntry(container);
      } else {
        final page = BoostPage.create(pageInfo, topContainer.routeFactory);
        topContainer.push(page);
      }
    }
    Logger.log(
        'push page, uniqueId=$uniqueId, existed=$container, withContainer=$withContainer, arguments:$arguments, $containers');
  }

  Future<void> popWithResult<T extends Object>(T? result) async {
    final String uniqueId = topContainer.topPage.pageInfo.uniqueId;
    final result = pop(uniqueId: uniqueId);
    if (result == true) {
      if (_pendingResult.containsKey(uniqueId)) {
        _pendingResult[uniqueId]?.complete(result);
        _pendingResult.remove(uniqueId);
      }
    }
  }

  Future<bool> popUntil(String uniqueId,
      {Map<dynamic, dynamic>? arguments}) async {
    final BoostContainer? container = _findContainerByUniqueId(uniqueId);
    if (container == null) {
      Logger.error('uniqueId=$uniqueId not find');
      return false;
    }
    final BoostPage? page = _findPageByUniqueId(uniqueId, container);
    if (page == null) {
      Logger.error('uniqueId=$uniqueId page not find');
      return false;
    }

    if (container != topContainer) {
      final CommonParams params = CommonParams()
        ..pageName = container.pageInfo.pageName
        ..uniqueId = container.pageInfo.uniqueId
        ..arguments = container.pageInfo.arguments;
      await _nativeRouterApi.popUtilRouter(params);
    }
    container.popUntil(page.pageInfo.pageName);
    Logger.log(
        'pop container, uniqueId=$uniqueId, arguments:$arguments, $container');
    return true;
  }

  bool pop({String? uniqueId, Map<dynamic, dynamic>? arguments}) {
    BoostContainer? container;
    if (uniqueId != null) {
      container = _findContainerByUniqueId(uniqueId);
      if (container == null) {
        Logger.error('uniqueId=$uniqueId not find');
        return false;
      }
    } else {
      container = topContainer;
    }

    if (container != topContainer) {
      return false;
    }
    if (container.pages.length > 1) {
      container.pop();
    } else {
      _notifyNativePop(container);
    }

    Logger.log(
        'pop container, uniqueId=$uniqueId, arguments:$arguments, $container');
    return true;
  }

  void enablePanGesture(String uniqueId, bool enable) {
    final PanGestureParams params = PanGestureParams()
      ..uniqueId = uniqueId
      ..enable = enable;
    nativeRouterApi.enablePanGesture(params);
  }

  void _notifyNativePop(BoostContainer container) async {
    Logger.log('_removeContainer ,  uniqueId=${container.pageInfo.uniqueId}');
    _containers.remove(container);
    _pendingPopcontainers.add(container);
    final CommonParams params = CommonParams()
      ..pageName = container.pageInfo.pageName
      ..uniqueId = container.pageInfo.uniqueId
      ..arguments = container.pageInfo.arguments;
    await _nativeRouterApi.popRoute(params);

    if (Platform.isAndroid) {
      _removeContainer(container.pageInfo.uniqueId,
          targetContainers: _pendingPopcontainers);
    }
  }

  void onForeground() {
    PageVisibilityBinding.instance
        .dispatchForegroundEvent(_getCurrentPageRoute());
  }

  void onBackground() {
    PageVisibilityBinding.instance
        .dispatchBackgroundEvent(_getCurrentPageRoute());
  }

  void onNativeViewShow({CommonParams? arg}) {
    final String? uniqueId = arg?.uniqueId;
    if (uniqueId != null) {
      if (topContainer.pageInfo.uniqueId != uniqueId) {
        return;
      }
    }
    PageVisibilityBinding.instance
        .dispatchPageHideEvent(_getCurrentPageRoute());
  }

  void onNativeViewHide({CommonParams? arg}) {
    PageVisibilityBinding.instance
        .dispatchPageShowEvent(_getCurrentPageRoute());
  }

  void removeRouter(String? uniqueId) {
    if (uniqueId != null) {
      _removeContainer(uniqueId, targetContainers: _pendingPopcontainers);
      _removeContainer(uniqueId, targetContainers: _containers);
    }
  }

  void _removeContainer(String uniqueId,
      {required List<BoostContainer> targetContainers}) {
    BoostContainer? container = _findContainer(targetContainers, uniqueId);
    if (container != null) {
      targetContainers.remove(container);
      detachContainer(container);
    }
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
    return _findContainer(_containers, uniqueId);
  }

  BoostContainer? _findContainer(
      List<BoostContainer> containers, String uniqueId) {
    try {
      return containers.singleWhere((BoostContainer element) =>
          (element.pageInfo.uniqueId == uniqueId) ||
          element.pages.any((BoostPage<dynamic> element) =>
              element.pageInfo.uniqueId == uniqueId));
    } catch (e) {
      Logger.logObject(e);
    }
    return null;
  }

  BoostPage? _findPageByUniqueId(String uniqueId, BoostContainer container) {
    try {
      return container.pages.singleWhere(
          (BoostPage element) => element.pageInfo.uniqueId == uniqueId);
    } catch (e) {
      Logger.logObject(e);
    }
    return null;
  }

  void detachContainer(BoostContainer container) {
    Route<dynamic>? route = container.pages.first.route;
    PageVisibilityBinding.instance.dispatchPageDestoryEvent(route);
    container.detach();
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
  List<BoostPage<dynamic>> _pageList;
  String _uniqueId;

  BoostNavigatorObserver(this._pageList, this._uniqueId);

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    //handle internal route
    PageVisibilityBinding.instance.dispatchPageShowEvent(route);
    PageVisibilityBinding.instance.dispatchPageHideEvent(previousRoute);
    super.didPush(route, previousRoute);
    _disablePanGesture();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (previousRoute != null) {
      PageVisibilityBinding.instance.dispatchPageHideEvent(route);
      PageVisibilityBinding.instance.dispatchPageShowEvent(previousRoute);
    }
    super.didPop(route, previousRoute);
    _enablePanGesture();
  }

  bool canDisable = true;

  void _disablePanGesture() {
    if (Platform.isIOS) {
      if (_pageList.length > 1 && canDisable) {
        BoostNavigator.of().enablePanGesture(_uniqueId, false);
        canDisable = false;
      }
    }
  }

  void _enablePanGesture() {
    if (Platform.isIOS) {
      if (_pageList.length == 1) {
        BoostNavigator.of().enablePanGesture(_uniqueId, true);
        canDisable = true;
      }
    }
  }
}
