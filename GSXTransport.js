// Read-only client for GSX Remote state notifications. Independently implemented.
(function (scope) {
    "use strict";
    function createGsxBellConnection(handlers) {
        var socket = null, retry = null, deadline = null, stopped = false;
        function cancelTimers() { clearTimeout(retry); clearTimeout(deadline); retry = deadline = null; }
        function detach() {
            var previous = socket; socket = null;
            if (previous) {
                previous.onopen = previous.onmessage = previous.onerror = previous.onclose = null;
                try { previous.close(); } catch (ignored) {}
            }
        }
        function failed(candidate) {
            if (stopped || socket !== candidate) return;
            cancelTimers(); detach();
            if (handlers.onClose) handlers.onClose();
            retry = setTimeout(connect, 1000);
        }
        function connect() {
            if (stopped) return;
            cancelTimers(); detach();
            var port = 8744;
            try {
                var configured = Number(SimVar.GetSimVarValue('L:FSDT_GSX_REMOTE_PORT', 'number'));
                if (isFinite(configured) && configured >= 1 && configured <= 65535) port = Math.round(configured);
            } catch (ignored) {}
            var candidate;
            try { candidate = new WebSocket('ws://127.0.0.1:' + port + '/'); }
            catch (ignored) { if (handlers.onClose) handlers.onClose(); retry = setTimeout(connect, 1000); return; }
            socket = candidate;
            deadline = setTimeout(function () { failed(candidate); }, 4000);
            candidate.onopen = function () {
                if (stopped || socket !== candidate) return;
                clearTimeout(deadline); deadline = null;
                try { candidate.send(JSON.stringify({type:'subscribe', channels:['state']})); }
                catch (ignored) { failed(candidate); return; }
                if (handlers.onOpen) handlers.onOpen();
            };
            candidate.onmessage = function (event) {
                if (stopped || socket !== candidate) return;
                var message;
                try { message = JSON.parse(event.data); } catch (ignored) { return; }
                if (handlers.onMessage) handlers.onMessage(message);
            };
            candidate.onerror = candidate.onclose = function () { failed(candidate); };
        }
        connect();
        return {
            isOpen: function () { return !stopped && socket !== null && socket.readyState === 1; },
            dispose: function () { stopped = true; cancelTimers(); detach(); }
        };
    }
    scope.createGsxBellConnection = createGsxBellConnection;
})(typeof window !== 'undefined' ? window : this);