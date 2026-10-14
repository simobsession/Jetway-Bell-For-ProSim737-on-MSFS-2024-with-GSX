class GSXJetwayBell extends BaseInstrument {
    constructor() {
        super();
        this.bellState = new GSXJetwayBellState();
        this.bellTransport = null;
        this.bellDisposed = false;
        this.lastBellValue = null;
        this.airportCode = '';
        this.soundAirports = Array.isArray(window.GSXBellAirports) ? window.GSXBellAirports : [];
        this.bellPreparedAt = null;
    }
    get templateID() { return 'GSXJetwayBellTemplate'; }
    get isInteractive() { return false; }
    connectedCallback() {
        super.connectedCallback();
        if (this.bellTransport && this.bellTransport.dispose) this.bellTransport.dispose();
        this.bellDisposed = false;
        SimVar.SetSimVarValue('L:GSX_BELL_GAUGE_LOADED', 'number', 1);
        SimVar.SetSimVarValue('L:GSX_BELL_VOLUME', 'number', 12.5);
        this.publishDoorMix();
        this.publishAirport('');
        this.bellState.disconnect();
        this.publishBell(false);
        this.bellTransport = createGsxBellConnection({
            onMessage: (message) => {
                if (this.bellDisposed) return;
                this.bellState.apply(message);
                if (message.type === 'snapshot') this.publishAirport(message.airport && message.airport.icao);
                if (message.type === 'patch' && message.path === '/airport') this.publishAirport(message.value && message.value.icao);
                if (message.type === 'patch' && message.path === '/airport/icao') this.publishAirport(message.value);
                this.publishBell(this.operationActive());
            },
            onClose: () => {
                this.bellState.disconnect();
                this.publishBell(false);
            }
        });
    }
    Update() {
        super.Update();
        this.publishDoorMix();
        if (!this.bellDisposed) this.publishBell(this.operationActive());
        if (!this.bellDisposed && this.bellTransport && !this.bellTransport.isOpen()) {
            this.bellState.disconnect();
            this.publishBell(false);
        }
    }
    operationActive() {
        // Native MSFS phases include automatic boarding/deboarding and hood motion.
        var moving = SimVar.GetSimVarValue('L:GSX_BELL_JETWAY_MOVING', 'number') > 0.5;
        return this.bellState.active() ||
            (this.bellState.connected && this.bellState.running && moving);
    }
    publishDoorMix() {
        // ProSim and GSX drive independent L1 position signals; either can open it.
        var position = SimVar.GetSimVarValue('L:B738_door_0', 'number');
        var simulatorPosition = SimVar.GetSimVarValue('INTERACTIVE POINT OPEN:0', 'percent');
        var prosimRatio = Number.isFinite(position) ? Math.max(0, Math.min(1, position / 200)) : 0;
        var simulatorRatio = Number.isFinite(simulatorPosition) ? Math.max(0, Math.min(1, simulatorPosition / 100)) : 0;
        var openness = Math.max(prosimRatio, simulatorRatio);
        var distanceVolume = SimVar.GetSimVarValue('L:GSX_BELL_VOLUME', 'number');
        var level = Number.isFinite(distanceVolume) ? Math.max(0, Math.min(100, distanceVolume)) : 12.5;
        // Keep idle curves silent; prepare the correct level before starting a voice.
        if (this.lastBellValue !== 1 && this.bellPreparedAt === null) level = 0;
        SimVar.SetSimVarValue('L:GSX_BELL_PLAYBACK_VOLUME', 'number', level);
        SimVar.SetSimVarValue('L:GSX_BELL_DOOR_OPEN_RATIO', 'number', openness);
        SimVar.SetSimVarValue('L:GSX_BELL_CLOSED_VOLUME', 'number', level * (1 - openness));
        SimVar.SetSimVarValue('L:GSX_BELL_OPEN_VOLUME', 'number', level * openness);
    }
    publishAirport(icao) {
        var code = (typeof icao === 'string' ? icao.toUpperCase() : '').slice(0, 8);
        this.airportCode = code;
        this.publishSoundSelection(this.lastBellValue === 1);
        for (var part = 0; part < 2; part++) {
            var packed = 0;
            for (var i = 0; i < 4; i++) {
                packed += (code.charCodeAt(part * 4 + i) || 0) * Math.pow(256, i);
            }
            SimVar.SetSimVarValue('L:GSX_BELL_AIRPORT_CODE_' + (part + 1), 'number', packed);
        }
    }
    publishSoundSelection(active) {
        var selected = this.soundAirports.indexOf(this.airportCode) >= 0 ? this.airportCode : '';
        SimVar.SetSimVarValue('L:GSX_JETWAY_BELL_DEFAULT_ACTIVE', 'number', active && !selected ? 1 : 0);
        this.soundAirports.forEach(function (code) {
            SimVar.SetSimVarValue('L:GSX_JETWAY_BELL_AIRPORT_' + code + '_ACTIVE', 'number', active && selected === code ? 1 : 0);
        });
    }
    publishBell(active) {
        var value = !this.bellDisposed && active ? 1 : 0;
        SimVar.SetSimVarValue('L:GSX_BELL_CONNECTED', 'number', this.bellState.connected && this.bellState.running ? 1 : 0);
        if (!value) {
            this.bellPreparedAt = null;
        } else if (this.lastBellValue !== 1) {
            if (this.bellPreparedAt === null) {
                this.bellPreparedAt = Date.now();
                this.publishDoorMix();
                return; // Let MSFS consume the volume curves while playback is still off.
            }
            if (Date.now() - this.bellPreparedAt < 60) return;
        }
        if (value === this.lastBellValue) return;
        this.lastBellValue = value;
        this.publishSoundSelection(value === 1);
        SimVar.SetSimVarValue('L:GSX_JETWAY_BELL_ACTIVE', 'number', value);
        if (!value) this.publishDoorMix();
        console.log('[GSX Jetway Bell] ' + (value ? 'operating' : 'silent'));
    }
    disconnectedCallback() {
        this.bellDisposed = true;
        if (this.bellTransport && this.bellTransport.dispose) this.bellTransport.dispose();
        SimVar.SetSimVarValue('L:GSX_BELL_GAUGE_LOADED', 'number', 0);
        this.bellState.disconnect();
        this.publishBell(false);
        super.disconnectedCallback();
    }
}
registerInstrument('gsx-jetway-bell', GSXJetwayBell);