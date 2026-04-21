const audioCtx = new (window.AudioContext || window.webkitAudioContext)();
let isMuted = false;

function playTone(freq, typeStr, startTimeOffset, duration, vol=1) {
    const osc = audioCtx.createOscillator();
    const gain = audioCtx.createGain();
    osc.connect(gain);
    gain.connect(audioCtx.destination);
    
    const now = audioCtx.currentTime + startTimeOffset;
    osc.type = typeStr;
    osc.frequency.setValueAtTime(freq, now);
    gain.gain.setValueAtTime(0, now);
    gain.gain.linearRampToValueAtTime(vol, now + 0.02);
    gain.gain.setValueAtTime(vol, now + duration - 0.02);
    gain.gain.linearRampToValueAtTime(0, now + duration);
    
    osc.start(now);
    osc.stop(now + duration);
}

function playBeep(type) {
    if (isMuted) return;
    if (audioCtx.state === 'suspended') audioCtx.resume();
    
    const theme = document.getElementById('sound-theme-select').value;
    
    if (theme === 'classic') {
        if (type === 'countdown') playTone(880, 'sine', 0, 0.1, 0.3);
        else if (type === 'workStart') { playTone(1046.5, 'sine', 0, 0.1, 0.8); playTone(1046.5, 'sine', 0.15, 0.1, 0.8); }
        else if (type === 'restStart') playTone(440, 'sine', 0, 0.8, 0.8);
        else if (type === 'complete') { playTone(523.25, 'sine', 0, 0.15, 0.8); playTone(659.25, 'sine', 0.15, 0.15, 0.8); playTone(783.99, 'sine', 0.30, 0.15, 0.8); playTone(1046.50, 'sine', 0.45, 0.6, 0.8); }
    } else if (theme === 'bell') {
        if (type === 'countdown') playTone(1046.5, 'sine', 0, 0.1, 0.2);
        else if (type === 'workStart') playTone(1318.5, 'sine', 0, 0.3, 0.5);
        else if (type === 'restStart') playTone(659.25, 'sine', 0, 0.8, 0.5);
        else if (type === 'complete') { playTone(523.25, 'sine', 0, 0.6, 0.4); playTone(659.25, 'sine', 0.1, 0.6, 0.4); playTone(783.99, 'sine', 0.2, 0.6, 0.4); playTone(1046.50, 'sine', 0.3, 1.0, 0.4); }
    } else if (theme === 'retro') {
        if (type === 'countdown') playTone(440, 'square', 0, 0.1, 0.1);
        else if (type === 'workStart') { playTone(880, 'square', 0, 0.1, 0.2); playTone(1760, 'square', 0.1, 0.1, 0.2); }
        else if (type === 'restStart') { playTone(440, 'square', 0, 0.2, 0.2); playTone(220, 'square', 0.2, 0.4, 0.2); }
        else if (type === 'complete') { playTone(1318.5, 'square', 0, 0.1, 0.2); playTone(1567.98, 'square', 0.1, 0.1, 0.2); playTone(2093, 'square', 0.2, 0.4, 0.2); }
    } else if (theme === 'synth') {
        if (type === 'countdown') playTone(220, 'sawtooth', 0, 0.1, 0.1);
        else if (type === 'workStart') { playTone(440, 'sawtooth', 0, 0.1, 0.2); playTone(659.25, 'sawtooth', 0.1, 0.2, 0.2); }
        else if (type === 'restStart') { playTone(220, 'sawtooth', 0, 0.6, 0.2); }
        else if (type === 'complete') { playTone(220, 'sawtooth', 0, 0.6, 0.2); playTone(329.63, 'sawtooth', 0, 0.6, 0.2); playTone(440, 'sawtooth', 0, 0.6, 0.2); }
    } else if (theme === 'cyber') {
        if (type === 'countdown') playTone(1760, 'triangle', 0, 0.05, 0.2);
        else if (type === 'workStart') { playTone(880, 'triangle', 0, 0.05, 0.4); playTone(1760, 'triangle', 0.05, 0.2, 0.4); }
        else if (type === 'restStart') { playTone(440, 'triangle', 0, 0.4, 0.4); playTone(220, 'triangle', 0.4, 0.4, 0.4); }
        else if (type === 'complete') { playTone(440, 'triangle', 0, 0.1, 0.4); playTone(880, 'triangle', 0.1, 0.1, 0.4); playTone(1760, 'triangle', 0.2, 0.4, 0.4); }
    }
}

// State
let isRunning = false;
let isWorkPhase = true; // true: Int1, false: Int2
let currentSet = 1;
let timeLeftMs = 0;
let totalPhaseTimeMs = 1;
let lastTickTime = 0;
let animationFrameId = null;
let soundPlayedForSecond = null; 

// Elements
const timeDisplay = document.getElementById('time-left');
const phaseDisplay = document.getElementById('current-phase-display');
const setCounterDisplay = document.getElementById('set-counter');
const progressCircle = document.querySelector('.progress-ring__circle');
const root = document.documentElement;

const int1MinInput = document.getElementById('int1-min');
const int1SecInput = document.getElementById('int1-sec');
const int2MinInput = document.getElementById('int2-min');
const int2SecInput = document.getElementById('int2-sec');

const int1Name = document.getElementById('int1-name');
const int2Name = document.getElementById('int2-name');

const btnStart = document.getElementById('btn-start');
const btnPause = document.getElementById('btn-pause');
const btnReset = document.getElementById('btn-reset');
const btnMute = document.getElementById('btn-mute');
const btnTestSound = document.getElementById('btn-test-sound');

const btnToggleSettings = document.getElementById('btn-toggle-settings');
const settingsPanel = document.getElementById('settings-panel');
const settingsSummary = document.getElementById('settings-summary');

const CIRCUMFERENCE = 2 * Math.PI * 45;

btnMute.addEventListener('click', () => {
    isMuted = !isMuted;
    btnMute.classList.toggle('muted', isMuted);
    btnMute.textContent = isMuted ? '🔇' : '🔊';
});

btnToggleSettings.addEventListener('click', () => {
    settingsPanel.classList.toggle('collapsed');
});

btnTestSound.addEventListener('click', () => {
    if (isRunning) return;
    // Play a sequence to preview the sounds
    playBeep('workStart');
    setTimeout(() => playBeep('countdown'), 600);
    setTimeout(() => playBeep('restStart'), 1200);
    setTimeout(() => playBeep('complete'), 2200);
});

function getIntervalTimeMs(isWork) {
    const minStr = isWork ? int1MinInput.value : int2MinInput.value;
    const secStr = isWork ? int1SecInput.value : int2SecInput.value;
    const min = parseInt(minStr) || 0;
    const sec = parseInt(secStr) || 0;
    return (min * 60 + sec) * 1000;
}

function updateDisplay() {
    const totalSecs = Math.ceil(timeLeftMs / 1000);
    const m = Math.floor(totalSecs / 60).toString().padStart(2, '0');
    const s = (totalSecs % 60).toString().padStart(2, '0');
    timeDisplay.textContent = `${m}:${s}`;
    
    // Set Counter
    const totalSets = parseInt(document.getElementById('total-sets').value) || 1;
    setCounterDisplay.textContent = `SET ${currentSet} / ${totalSets}`;
    
    // Progress Ring
    const progress = Math.max(0, Math.min(1, timeLeftMs / totalPhaseTimeMs));
    const offset = CIRCUMFERENCE - (progress * CIRCUMFERENCE);
    progressCircle.style.strokeDashoffset = offset;
    
    if (isRunning || timeLeftMs < getIntervalTimeMs(isWorkPhase)) {
        phaseDisplay.textContent = isWorkPhase ? int1Name.value : int2Name.value;
        const color = isWorkPhase ? 'var(--color-int1)' : 'var(--color-int2)';
        root.style.setProperty('--active-color', color);
    } else {
        phaseDisplay.textContent = 'READY';
        root.style.setProperty('--active-color', 'var(--color-ready)');
        progressCircle.style.strokeDashoffset = 0;
    }
}

function switchPhase() {
    isWorkPhase = !isWorkPhase;
    
    if (isWorkPhase) {
        currentSet++;
        const totalSets = parseInt(document.getElementById('total-sets').value) || 1;
        if (currentSet > totalSets) {
            isRunning = false;
            btnPause.classList.add('hidden');
            btnStart.classList.remove('hidden');
            document.querySelectorAll('.up-btn, .down-btn, .name-input').forEach(el => el.disabled = false);
            currentSet = totalSets;
            updateDisplay();
            playBeep('complete'); // 完了音
            return;
        }
        playBeep('workStart'); // 次はWORK
    } else {
        playBeep('restStart'); // 次はREST
    }
    
    totalPhaseTimeMs = getIntervalTimeMs(isWorkPhase);
    if (totalPhaseTimeMs === 0) totalPhaseTimeMs = 1000; // prevent div by 0
    timeLeftMs = totalPhaseTimeMs;
    soundPlayedForSecond = null;
}

function tick(timestamp) {
    if (!lastTickTime) lastTickTime = timestamp;
    const delta = timestamp - lastTickTime;
    lastTickTime = timestamp;
    
    if (isRunning) {
        timeLeftMs -= delta;
        
        const currentSec = Math.ceil(timeLeftMs / 1000);
        if (currentSec <= 3 && currentSec > 0) {
            if (soundPlayedForSecond !== currentSec) {
                playBeep('countdown'); // カウントダウン音
                soundPlayedForSecond = currentSec;
            }
        }
        
        if (timeLeftMs <= 0) {
            switchPhase();
            updateDisplay();
        }
    }
    
    updateDisplay();
    animationFrameId = requestAnimationFrame(tick);
}

function startTimer() {
    if (audioCtx.state === 'suspended') audioCtx.resume();
    
    if (!isRunning) {
        if (timeLeftMs <= 0 || (currentSet >= (parseInt(document.getElementById('total-sets').value) || 1) && !isWorkPhase && timeLeftMs <= 0)) {
            // Restart from beginning if fully finished
            isWorkPhase = true;
            currentSet = 1;
            totalPhaseTimeMs = getIntervalTimeMs(true);
            if (totalPhaseTimeMs === 0) totalPhaseTimeMs = 1000;
            timeLeftMs = totalPhaseTimeMs;
            soundPlayedForSecond = null;
        }
        isRunning = true;
        lastTickTime = performance.now();
        
        if (timeLeftMs === totalPhaseTimeMs && currentSet === 1 && isWorkPhase) {
             playBeep('workStart'); // 初回の開始音
        }
        
        if (!animationFrameId) {
            animationFrameId = requestAnimationFrame(tick);
        }
        
        btnStart.classList.add('hidden');
        btnPause.classList.remove('hidden');
        
        document.querySelectorAll('.up-btn, .down-btn, .name-input').forEach(el => el.disabled = true);
    }
}

function pauseTimer() {
    isRunning = false;
    btnPause.classList.add('hidden');
    btnStart.classList.remove('hidden');
}

function resetTimer() {
    isRunning = false;
    if (animationFrameId) {
        cancelAnimationFrame(animationFrameId);
        animationFrameId = null;
    }
    isWorkPhase = true;
    currentSet = 1;
    totalPhaseTimeMs = getIntervalTimeMs(true);
    if (totalPhaseTimeMs === 0) totalPhaseTimeMs = 1000;
    timeLeftMs = totalPhaseTimeMs;
    soundPlayedForSecond = null;
    lastTickTime = 0;
    
    btnPause.classList.add('hidden');
    btnStart.classList.remove('hidden');
    
    document.querySelectorAll('.up-btn, .down-btn, .name-input').forEach(el => el.disabled = false);
    updateDisplay();
}

btnStart.addEventListener('click', startTimer);
btnPause.addEventListener('click', pauseTimer);
btnReset.addEventListener('click', resetTimer);

// Make adjustTime globally available for inline onclick
window.adjustTime = function(inputId, delta) {
    if (isRunning) return;
    const input = document.getElementById(inputId);
    let val = parseInt(input.value) || 0;
    const max = inputId.includes('sec') ? 59 : 99;
    
    val += delta;
    if (val < 0) val = max;
    if (val > max) val = 0;
    
    input.value = val;
    totalPhaseTimeMs = getIntervalTimeMs(isWorkPhase);
    timeLeftMs = totalPhaseTimeMs;
    saveSettings();
    updateDisplay();
};

function saveSettings() {
    const settings = {
        int1Name: int1Name.value,
        int1Min: int1MinInput.value,
        int1Sec: int1SecInput.value,
        int2Name: int2Name.value,
        int2Min: int2MinInput.value,
        int2Sec: int2SecInput.value,
        totalSets: document.getElementById('total-sets').value,
        soundTheme: document.getElementById('sound-theme-select').value
    };
    localStorage.setItem('intervalTimerProSettings', JSON.stringify(settings));
    
    // Update summary string
    const wM = int1MinInput.value;
    const wS = int1SecInput.value.padStart(2, '0');
    const rM = int2MinInput.value;
    const rS = int2SecInput.value.padStart(2, '0');
    settingsSummary.textContent = `W ${wM}:${wS} | R ${rM}:${rS} (${settings.totalSets} SETS)`;
}

function loadSettings() {
    const saved = localStorage.getItem('intervalTimerProSettings');
    if (saved) {
        try {
            const settings = JSON.parse(saved);
            if (settings.int1Name) int1Name.value = settings.int1Name;
            if (settings.int1Min) int1MinInput.value = settings.int1Min;
            if (settings.int1Sec) int1SecInput.value = settings.int1Sec;
            if (settings.int2Name) int2Name.value = settings.int2Name;
            if (settings.int2Min) int2MinInput.value = settings.int2Min;
            if (settings.int2Sec) int2SecInput.value = settings.int2Sec;
            if (settings.totalSets) document.getElementById('total-sets').value = settings.totalSets;
            if (settings.soundTheme) document.getElementById('sound-theme-select').value = settings.soundTheme;
            
            // Initial summary update
            const wM = int1MinInput.value;
            const wS = int1SecInput.value.padStart(2, '0');
            const rM = int2MinInput.value;
            const rS = int2SecInput.value.padStart(2, '0');
            settingsSummary.textContent = `W ${wM}:${wS} | R ${rM}:${rS} (${document.getElementById('total-sets').value} SETS)`;
        } catch (e) {
            console.error("Failed to load settings", e);
        }
    } else {
        // Init summary if no settings
        settingsSummary.textContent = `W 10:00 | R 1:00 (10 SETS)`;
    }
}

// Ensure names update if changed while paused
[int1Name, int2Name].forEach(input => {
    input.addEventListener('input', () => {
        saveSettings();
        if (!isRunning) updateDisplay();
    });
});

document.getElementById('sound-theme-select').addEventListener('change', saveSettings);

// Handle Android Back Button
window.addEventListener('popstate', (e) => {
    if (isRunning) {
        pauseTimer();
        const quit = confirm("タイマーが実行中です。終了しますか？");
        if (!quit) {
            history.pushState(null, document.title, location.href);
            return;
        }
    }
    // If not running or confirmed, allow default (or we just let them stay but close)
});
history.pushState(null, document.title, location.href);

loadSettings();
resetTimer();
