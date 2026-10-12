/* Reads the documented GSX Remote v2 service state. Does not issue GSX commands. */
(function (root) {
    'use strict';
    function operating(service) {
        if (!service || service.id !== 'OperateJetways') return false;
        return [4, 5, 7].indexOf(Number(service.stateRaw)) !== -1 ||
            ['requested', 'performing', 'completing'].indexOf(service.state) !== -1;
    }
    function State() { this.services = []; this.running = false; this.connected = false; }
    State.prototype.apply = function (message) {
        if (!message) return;
        if (message.type === 'hello') this.running = message.gsxRunning === true;
        if (message.type === 'snapshot') {
            this.services = Array.isArray(message.services) ? message.services : [];
            this.connected = true;
        }
        if (message.type === 'patch' && message.path === '/services')
            this.services = Array.isArray(message.value) ? message.value : [];
        if (message.type === 'event' && message.topic === 'engine') {
            this.running = message.gsxRunning === true && !message.restarting;
            if (!this.running) this.services = [];
        }
    };
    State.prototype.disconnect = function () { this.connected = false; this.running = false; this.services = []; };
    State.prototype.active = function () {
        return this.connected && this.running && this.services.some(operating);
    };
    State.prototype.raw = function () {
        var service = this.services.find(function (s) { return s && s.id === 'OperateJetways'; });
        return service ? Number(service.stateRaw) || 0 : 0;
    };
    root.GSXJetwayBellState = State;
    if (typeof module !== 'undefined' && module.exports) module.exports = { State: State, operating: operating };
})(typeof window !== 'undefined' ? window : globalThis);