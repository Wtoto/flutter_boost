/*
 * The MIT License (MIT)
 *
 * Copyright (c) 2019 Alibaba Group
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

package com.taobao.idlefish.flutterboost.messageing;

import com.taobao.idlefish.flutterboost.messageing.base.MessageResult;

import java.util.HashMap;
import java.util.Map;

import io.flutter.plugin.common.MethodChannel;

public class NavigationService {

    public static MethodChannel methodChannel = null;

    public static void onNativePageResult(final MessageResult<Boolean> result, String uniqueId, String key, Map resultData, Map params) {
        Map<String, Object> args = new HashMap<>();
        args.put("uniqueId", uniqueId);
        args.put("key", key);
        args.put("resultData", resultData);
        args.put("params", params);
        methodChannel.invokeMethod("onNativePageResult", args, new MethodChannel.Result() {
            @Override
            public void success(Object o) {
                if (o instanceof Boolean) {
                    result.success((Boolean) o);
                } else {
                    result.error("return type error code dart code", "", "");
                }
            }

            @Override
            public void error(String s, String s1, Object o) {
                if (result != null) {
                    result.error(s, s1, o);
                }
            }

            @Override
            public void notImplemented() {
                if (result != null) {
                    result.notImplemented();
                }
            }
        });
    }

    public static void didShowPageContainer(final MessageResult<Boolean> result, String pageName, Map params, String uniqueId) {
        Map<String, Object> args = new HashMap<>();
        args.put("pageName", pageName);
        args.put("params", params);
        args.put("uniqueId", uniqueId);
        methodChannel.invokeMethod("didShowPageContainer", args, new MethodChannel.Result() {
            @Override
            public void success(Object o) {
                if (o instanceof Boolean) {
                    result.success((Boolean) o);
                } else {
                    result.error("return type error code dart code", "", "");
                }
            }

            @Override
            public void error(String s, String s1, Object o) {
                if (result != null) {
                    result.error(s, s1, o);
                }
            }

            @Override
            public void notImplemented() {
                if (result != null) {
                    result.notImplemented();
                }
            }
        });
    }

    public static void willShowPageContainer(final MessageResult<Boolean> result, String pageName, Map params, String uniqueId) {
        Map<String, Object> args = new HashMap<>();
        args.put("pageName", pageName);
        args.put("params", params);
        args.put("uniqueId", uniqueId);
        methodChannel.invokeMethod("willShowPageContainer", args, new MethodChannel.Result() {
            @Override
            public void success(Object o) {
                if (o instanceof Boolean) {
                    result.success((Boolean) o);
                } else {
                    result.error("return type error code dart code", "", "");
                }
            }

            @Override
            public void error(String s, String s1, Object o) {
                if (result != null) {
                    result.error(s, s1, o);
                }
            }

            @Override
            public void notImplemented() {
                if (result != null) {
                    result.notImplemented();
                }
            }
        });
    }

    public static void willDisappearPageContainer(final MessageResult<Boolean> result, String pageName, Map params, String uniqueId) {
        Map<String, Object> args = new HashMap<>();
        args.put("pageName", pageName);
        args.put("params", params);
        args.put("uniqueId", uniqueId);
        methodChannel.invokeMethod("willDisappearPageContainer", args, new MethodChannel.Result() {
            @Override
            public void success(Object o) {
                if (o instanceof Boolean) {
                    result.success((Boolean) o);
                } else {
                    result.error("return type error code dart code", "", "");
                }
            }

            @Override
            public void error(String s, String s1, Object o) {
                if (result != null) {
                    result.error(s, s1, o);
                }
            }

            @Override
            public void notImplemented() {
                if (result != null) {
                    result.notImplemented();
                }
            }
        });
    }

    public static void didDisappearPageContainer(final MessageResult<Boolean> result, String pageName, Map params, String uniqueId) {
        Map<String, Object> args = new HashMap<>();
        args.put("pageName", pageName);
        args.put("params", params);
        args.put("uniqueId", uniqueId);
        methodChannel.invokeMethod("didDisappearPageContainer", args, new MethodChannel.Result() {
            @Override
            public void success(Object o) {
                if (o instanceof Boolean) {
                    result.success((Boolean) o);
                } else {
                    result.error("return type error code dart code", "", "");
                }
            }

            @Override
            public void error(String s, String s1, Object o) {
                if (result != null) {
                    result.error(s, s1, o);
                }
            }

            @Override
            public void notImplemented() {
                if (result != null) {
                    result.notImplemented();
                }
            }
        });
    }

    public static void didInitPageContainer(final MessageResult<Boolean> result, String pageName, Map params, String uniqueId) {
        Map<String, Object> args = new HashMap<>();
        args.put("pageName", pageName);
        args.put("params", params);
        args.put("uniqueId", uniqueId);
        methodChannel.invokeMethod("didInitPageContainer", args, new MethodChannel.Result() {
            @Override
            public void success(Object o) {
                if (o instanceof Boolean) {
                    result.success((Boolean) o);
                } else {
                    result.error("return type error code dart code", "", "");
                }
            }

            @Override
            public void error(String s, String s1, Object o) {
                if (result != null) {
                    result.error(s, s1, o);
                }
            }

            @Override
            public void notImplemented() {
                if (result != null) {
                    result.notImplemented();
                }
            }
        });
    }

    public static void willDeallocPageContainer(final MessageResult<Boolean> result, String pageName, Map params, String uniqueId) {
        Map<String, Object> args = new HashMap<>();
        args.put("pageName", pageName);
        args.put("params", params);
        args.put("uniqueId", uniqueId);
        methodChannel.invokeMethod("willDeallocPageContainer", args, new MethodChannel.Result() {
            @Override
            public void success(Object o) {
                if (o instanceof Boolean) {
                    result.success((Boolean) o);
                } else {
                    result.error("return type error code dart code", "", "");
                }
            }

            @Override
            public void error(String s, String s1, Object o) {
                if (result != null) {
                    result.error(s, s1, o);
                }
            }

            @Override
            public void notImplemented() {
                if (result != null) {
                    result.notImplemented();
                }
            }
        });
    }
}