const audioCtx = new (window.AudioContext || window.webkitAudioContext)();

function playBeep(type) {
    if (audioCtx.state === 'suspended') {
        audioCtx.resume();
    }
    
    const osc = audioCtx.createOscillator();
    const gain = audioCtx.createGain();
    
    osc.connect(gain);
    gain.connect(audioCtx.destination);
    
    const now = audioCtx.currentTime;
    
    if (type === 'short') {
        // 短い「ピッ」 (100ms)
        osc.type = 'sine';
        osc.frequency.setValueAtTime(880, now); // A5
        gain.gain.setValueAtTime(0, now);
        gain.gain.linearRampToValueAtTime(1, now + 0.02);
        gain.gain.setValueAtTime(1, now + 0.08);
        gain.gain.linearRampToValueAtTime(0, now + 0.1);
        
        osc.start(now);
        osc.stop(now + 0.1);
    } else if (type === 'long') {
        // 長い「ピーー」 (800ms)
        osc.type = 'sine';
        osc.frequency.setValueAtTime(1046.50, now); // C6
        gain.gain.setValueAtTime(0, now);
        gain.gain.linearRampToValueAtTime(1, now + 0.05);
        gain.gain.setValueAtTime(1, now + 0.7);
        gain.gain.linearRampToValueAtTime(0, now + 0.8);
        
        osc.start(now);
        osc.stop(now + 0.8);
    }
}

// State
let isRunning = false;
let isWorkPhase = true; // true: Interval 1, false: Interval 2
let timeLeftMs = 0;
let lastTickTime = 0;
let animationFrameId = null;

// サウンドの多重再生を防ぐためのフラグ (現在の秒数を記録)
let soundPlayedForSecond = null; 

// DOM Elements
const timeDisplay = document.getElementById('time-left');
const phaseDisplay = document.getElementById('current-phase');
const timerContainer = document.getElementById('timer-display');

const int1MinInput = document.getElementById('int1-min');
const int1SecInput = document.getElementById('int1-sec');
const int2MinInput = document.getElementById('int2-min');
const int2SecInput = document.getElementById('int2-sec');

const btnStart = document.getElementById('btn-start');
const btnPause = document.getElementById('btn-pause');
const btnReset = document.getElementById('btn-reset');

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
    
    if (isRunning || timeLeftMs < getIntervalTimeMs(isWorkPhase)) {
        phaseDisplay.textContent = isWorkPhase ? 'INTERVAL 1' : 'INTERVAL 2';
        if (isWorkPhase) {
            timerContainer.classList.add('work-phase');
            timerContainer.classList.remove('rest-phase');
        } else {
            timerContainer.classList.add('rest-phase');
            timerContainer.classList.remove('work-phase');
        }
    } else {
        phaseDisplay.textContent = 'READY';
        timerContainer.classList.remove('work-phase', 'rest-phase');
    }
}

function switchPhase() {
    isWorkPhase = !isWorkPhase;
    timeLeftMs = getIntervalTimeMs(isWorkPhase);
    soundPlayedForSecond = null;
}

function tick(timestamp) {
    if (!lastTickTime) lastTickTime = timestamp;
    const delta = timestamp - lastTickTime;
    lastTickTime = timestamp;
    
    if (isRunning) {
        timeLeftMs -= delta;
        
        // Handle sound
        const currentSec = Math.ceil(timeLeftMs / 1000);
        if (currentSec <= 3 && currentSec > 0) {
            // 残り3秒、2秒、1秒で短いピープ音
            if (soundPlayedForSecond !== currentSec) {
                playBeep('short');
                soundPlayedForSecond = currentSec;
            }
        }
        
        if (timeLeftMs <= 0) {
            // 0秒で長いピープ音とフェーズ切り替え
            playBeep('long');
            switchPhase();
            updateDisplay(); // 即座にUIを更新
        }
    }
    
    updateDisplay();
    animationFrameId = requestAnimationFrame(tick);
}

function startTimer() {
    if (audioCtx.state === 'suspended') {
        audioCtx.resume();
    }
    
    if (!isRunning) {
        if (timeLeftMs <= 0) {
            isWorkPhase = true;
            timeLeftMs = getIntervalTimeMs(true);
            soundPlayedForSecond = null;
        }
        isRunning = true;
        lastTickTime = performance.now();
        if (!animationFrameId) {
            animationFrameId = requestAnimationFrame(tick);
        }
        
        btnStart.classList.add('hidden');
        btnPause.classList.remove('hidden');
        
        // 動作中はインプットを無効化
        document.querySelectorAll('input').forEach(i => i.disabled = true);
        document.querySelectorAll('.ctrl-btn').forEach(b => b.disabled = true);
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
    timeLeftMs = getIntervalTimeMs(true);
    soundPlayedForSecond = null;
    lastTickTime = 0;
    
    btnPause.classList.add('hidden');
    btnStart.classList.remove('hidden');
    
    // インプットを有効化
    document.querySelectorAll('input').forEach(i => i.disabled = false);
    document.querySelectorAll('.ctrl-btn').forEach(b => b.disabled = false);
    
    updateDisplay();
}

btnStart.addEventListener('click', startTimer);
btnPause.addEventListener('click', pauseTimer);
btnReset.addEventListener('click', resetTimer);

// 入力値が変わったときに表示を更新する（停止中のみ）
const inputs = [int1MinInput, int1SecInput, int2MinInput, int2SecInput];
inputs.forEach(input => {
    input.addEventListener('change', () => {
        if (!isRunning) {
            timeLeftMs = getIntervalTimeMs(isWorkPhase);
            updateDisplay();
        }
    });
});

function adjustTime(inputId, delta) {
    if (isRunning) return;
    const input = document.getElementById(inputId);
    const minVal = parseInt(input.min) || 0;
    const maxVal = parseInt(input.max) || 99;
    let currentVal = parseInt(input.value) || 0;
    
    currentVal += delta;
    if (currentVal < minVal) currentVal = maxVal;
    if (currentVal > maxVal) currentVal = minVal;
    
    input.value = currentVal;
    
    if (!isRunning) {
        timeLeftMs = getIntervalTimeMs(isWorkPhase);
        updateDisplay();
    }
}

// 初期表示のセット
resetTimer();
