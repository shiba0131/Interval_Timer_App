const canvas = document.getElementById('gameCanvas');
const ctx = canvas.getContext('2d', { alpha: false });

// Simple Web Audio API sound generator
const audioCtx = new (window.AudioContext || window.webkitAudioContext)();

function playSound(type) {
    if (audioCtx.state === 'suspended') {
        audioCtx.resume();
    }
    
    const oscillator = audioCtx.createOscillator();
    const gainNode = audioCtx.createGain();
    
    oscillator.connect(gainNode);
    gainNode.connect(audioCtx.destination);
    
    const now = audioCtx.currentTime;
    
    if (type === 'shoot') {
        oscillator.type = 'square';
        oscillator.frequency.setValueAtTime(880, now);
        oscillator.frequency.exponentialRampToValueAtTime(110, now + 0.1);
        gainNode.gain.setValueAtTime(0.05, now);
        gainNode.gain.exponentialRampToValueAtTime(0.01, now + 0.1);
        oscillator.start(now);
        oscillator.stop(now + 0.1);
    } else if (type === 'explosion') {
        oscillator.type = 'sawtooth';
        oscillator.frequency.setValueAtTime(100, now);
        oscillator.frequency.exponentialRampToValueAtTime(10, now + 0.3);
        gainNode.gain.setValueAtTime(0.1, now);
        gainNode.gain.exponentialRampToValueAtTime(0.01, now + 0.3);
        oscillator.start(now);
        oscillator.stop(now + 0.3);
    } else if (type === 'enemyShoot') {
        oscillator.type = 'square';
        oscillator.frequency.setValueAtTime(440, now);
        oscillator.frequency.exponentialRampToValueAtTime(55, now + 0.15);
        gainNode.gain.setValueAtTime(0.03, now);
        gainNode.gain.exponentialRampToValueAtTime(0.01, now + 0.15);
        oscillator.start(now);
        oscillator.stop(now + 0.15);
    } else if (type === 'playerExplosion') {
        oscillator.type = 'sawtooth';
        oscillator.frequency.setValueAtTime(150, now);
        oscillator.frequency.exponentialRampToValueAtTime(1, now + 1.5);
        gainNode.gain.setValueAtTime(0.5, now);
        gainNode.gain.exponentialRampToValueAtTime(0.01, now + 1.5);
        
        const osc2 = audioCtx.createOscillator();
        const gain2 = audioCtx.createGain();
        osc2.type = 'square';
        osc2.frequency.setValueAtTime(50, now);
        osc2.frequency.exponentialRampToValueAtTime(5, now + 1.5);
        gain2.gain.setValueAtTime(0.5, now);
        gain2.gain.exponentialRampToValueAtTime(0.01, now + 1.5);
        
        osc2.connect(gain2);
        gain2.connect(audioCtx.destination);
        osc2.start(now);
        osc2.stop(now + 1.5);
        
        oscillator.start(now);
        oscillator.stop(now + 1.5);
    } else if (type === 'start') {
        oscillator.type = 'sine';
        oscillator.frequency.setValueAtTime(440, now);
        oscillator.frequency.exponentialRampToValueAtTime(880, now + 0.2);
        gainNode.gain.setValueAtTime(0.1, now);
        gainNode.gain.exponentialRampToValueAtTime(0.01, now + 0.2);
        oscillator.start(now);
        oscillator.stop(now + 0.2);
    }
}

// BGM logic
let nextNoteTime = 0;
let currentBGMNoteIndex = 0;
let bgmPlaying = false;
// Sequence: A2, C3, A2, D3, A2, E3, D3, C3
const bgmSequence = [110.00, 130.81, 110.00, 146.83, 110.00, 164.81, 146.83, 130.81]; 
const bgmTempo = 140; // BPM
const bgmSecondsPerBeat = 60.0 / bgmTempo;
const bgmNoteLength = 0.5; // 8th notes

function scheduleNote() {
    if (!bgmPlaying) return;
    while (nextNoteTime < audioCtx.currentTime + 0.1) {
        const osc = audioCtx.createOscillator();
        const gain = audioCtx.createGain();
        
        const filter = audioCtx.createBiquadFilter();
        filter.type = 'lowpass';
        // Base frequency 400Hz, increase with level
        filter.frequency.value = 400 + ((gameState.level || 1) * 50);
        
        osc.connect(filter);
        filter.connect(gain);
        gain.connect(audioCtx.destination);
        
        osc.type = 'sawtooth';
        osc.frequency.value = bgmSequence[currentBGMNoteIndex];
        
        // Slight ducking effect
        gain.gain.setValueAtTime(0.05, nextNoteTime);
        gain.gain.exponentialRampToValueAtTime(0.001, nextNoteTime + (bgmSecondsPerBeat * bgmNoteLength) - 0.05);
        
        osc.start(nextNoteTime);
        osc.stop(nextNoteTime + (bgmSecondsPerBeat * bgmNoteLength));
        
        nextNoteTime += bgmSecondsPerBeat * bgmNoteLength;
        currentBGMNoteIndex = (currentBGMNoteIndex + 1) % bgmSequence.length;
    }
}

function startBGM() {
    if (bgmPlaying) return;
    if (audioCtx.state === 'suspended') {
        audioCtx.resume();
    }
    bgmPlaying = true;
    currentBGMNoteIndex = 0;
    nextNoteTime = audioCtx.currentTime + 0.1;
}

function stopBGM() {
    bgmPlaying = false;
}

function resizeCanvas() {
    const ratio = 16 / 9;
    let width = window.innerWidth * 0.9;
    let height = window.innerHeight * 0.9;
    if (width / height > ratio) {
        width = height * ratio;
    } else {
        height = width / ratio;
    }
    canvas.width = 800;
    canvas.height = 600;
    canvas.style.width = width + 'px';
    canvas.style.height = height + 'px';
}

window.addEventListener('resize', resizeCanvas);
resizeCanvas();

const KEYS = {
    ArrowLeft: false,
    ArrowRight: false,
    Space: false,
    a: false,
    d: false
};

window.addEventListener('keydown', (e) => {
    if (KEYS.hasOwnProperty(e.key) || KEYS.hasOwnProperty(e.code) || e.key === 'a' || e.key === 'd') {
        if(e.code === 'Space') KEYS.Space = true;
        if(e.key === 'ArrowLeft') KEYS.ArrowLeft = true;
        if(e.key === 'ArrowRight') KEYS.ArrowRight = true;
        if(e.key === 'a') KEYS.a = true;
        if(e.key === 'd') KEYS.d = true;
    }
});

window.addEventListener('keyup', (e) => {
    if (KEYS.hasOwnProperty(e.key) || KEYS.hasOwnProperty(e.code) || e.key === 'a' || e.key === 'd') {
        if(e.code === 'Space') KEYS.Space = false;
        if(e.key === 'ArrowLeft') KEYS.ArrowLeft = false;
        if(e.key === 'ArrowRight') KEYS.ArrowRight = false;
        if(e.key === 'a') KEYS.a = false;
        if(e.key === 'd') KEYS.d = false;
    }
});

class Player {
    constructor(x, y) {
        this.x = x;
        this.y = y;
        this.width = 40;
        this.height = 30;
        this.speed = 6;
        this.cooldown = 0;
        this.color = '#0ff';
    }

    update() {
        if (KEYS.ArrowLeft || KEYS.a) this.x -= this.speed;
        if (KEYS.ArrowRight || KEYS.d) this.x += this.speed;

        this.x = Math.max(this.width / 2, Math.min(canvas.width - this.width / 2, this.x));

        if (this.cooldown > 0) this.cooldown--;
    }

    draw(ctx) {
        ctx.save();
        ctx.translate(this.x, this.y);
        
        ctx.shadowBlur = 15;
        ctx.shadowColor = this.color;
        ctx.fillStyle = this.color;

        ctx.beginPath();
        ctx.moveTo(0, -this.height / 2);
        ctx.lineTo(this.width / 2, this.height / 2);
        ctx.lineTo(-this.width / 2, this.height / 2);
        ctx.closePath();
        ctx.fill();

        ctx.restore();
    }
}

class Bullet {
    constructor(x, y, isEnemy = false) {
        this.x = x;
        this.y = y;
        this.width = 4;
        this.height = 15;
        this.speed = isEnemy ? 5 : -10;
        this.isEnemy = isEnemy;
        this.color = isEnemy ? '#f0f' : '#0ff';
    }

    update() {
        this.y += this.speed;
    }

    draw(ctx) {
        ctx.save();
        ctx.shadowBlur = 10;
        ctx.shadowColor = this.color;
        ctx.fillStyle = this.color;
        ctx.fillRect(this.x - this.width / 2, this.y - this.height / 2, this.width, this.height);
        ctx.restore();
    }
}

class Invader {
    constructor(x, y) {
        this.x = x;
        this.y = y;
        this.width = 30;
        this.height = 30;
        this.color = '#f0f';
    }

    draw(ctx) {
        ctx.save();
        ctx.translate(this.x, this.y);
        
        ctx.shadowBlur = 15;
        ctx.shadowColor = this.color;
        ctx.fillStyle = this.color;

        ctx.beginPath();
        ctx.moveTo(-this.width/2, -this.height/2);
        ctx.lineTo(this.width/2, -this.height/2);
        ctx.lineTo(this.width/2, this.height/2);
        ctx.lineTo(-this.width/2, this.height/2);
        ctx.closePath();
        ctx.fill();
        
        // Eye
        ctx.fillStyle = '#000';
        ctx.fillRect(-5, -5, 10, 10);

        ctx.restore();
    }
}

class Particle {
    constructor(x, y, color) {
        this.x = x;
        this.y = y;
        this.vx = (Math.random() - 0.5) * 8;
        this.vy = (Math.random() - 0.5) * 8;
        this.life = 1.0;
        this.decay = Math.random() * 0.05 + 0.02;
        this.color = color;
        this.size = Math.random() * 3 + 1;
    }

    update() {
        this.x += this.vx;
        this.y += this.vy;
        this.life -= this.decay;
    }

    draw(ctx) {
        ctx.save();
        ctx.globalAlpha = this.life;
        ctx.fillStyle = this.color;
        ctx.shadowBlur = 5;
        ctx.shadowColor = this.color;
        ctx.beginPath();
        ctx.arc(this.x, this.y, this.size, 0, Math.PI * 2);
        ctx.fill();
        ctx.restore();
    }
}

const gameState = {
    player: null,
    bullets: [],
    invaders: [],
    particles: [],
    stars: [],
    score: 0,
    state: 'start', // start, playing, gameover
    invaderDirection: 1,
    invaderSpeed: 1,
    level: 1
};

// Initialize stars
for(let i=0; i<100; i++) {
    gameState.stars.push({
        x: Math.random() * 800,
        y: Math.random() * 600,
        size: Math.random() * 2,
        speed: Math.random() * 2 + 0.5
    });
}

function spawnInvaders(level) {
    const rows = Math.min(6, 3 + level);
    const cols = 10;
    const startX = 100;
    const startY = 80;
    const paddingX = 60;
    const paddingY = 50;

    gameState.invaders = [];
    for (let r = 0; r < rows; r++) {
        for (let c = 0; c < cols; c++) {
            gameState.invaders.push(new Invader(startX + c * paddingX, startY + r * paddingY));
        }
    }
}

function initGame() {
    gameState.player = new Player(canvas.width / 2, canvas.height - 50);
    gameState.bullets = [];
    gameState.particles = [];
    gameState.score = 0;
    gameState.invaderDirection = 1;
    gameState.invaderSpeed = 1;
    gameState.level = 1;
    updateScore();
    spawnInvaders(gameState.level);
}

function createExplosion(x, y, color) {
    for (let i = 0; i < 20; i++) {
        gameState.particles.push(new Particle(x, y, color));
    }
}

function updateScore() {
    document.getElementById('score').innerText = gameState.score;
}

function checkCollision(rect1, rect2) {
    return rect1.x - rect1.width/2 < rect2.x + rect2.width/2 &&
           rect1.x + rect1.width/2 > rect2.x - rect2.width/2 &&
           rect1.y - rect1.height/2 < rect2.y + rect2.height/2 &&
           rect1.y + rect1.height/2 > rect2.y - rect2.height/2;
}

function update() {
    // Update stars regardless of game state
    gameState.stars.forEach(star => {
        star.y += star.speed;
        if(star.y > canvas.height) {
            star.y = 0;
            star.x = Math.random() * canvas.width;
        }
    });

    // Update particles
    for (let i = gameState.particles.length - 1; i >= 0; i--) {
        const particle = gameState.particles[i];
        particle.update();
        if (particle.life <= 0) {
            gameState.particles.splice(i, 1);
        }
    }

    if (gameState.state !== 'playing') return;

    gameState.player.update();

    if (KEYS.Space && gameState.player.cooldown <= 0) {
        gameState.bullets.push(new Bullet(gameState.player.x, gameState.player.y - gameState.player.height/2));
        playSound('shoot');
        gameState.player.cooldown = 15;
    }

    // Update bullets
    for (let i = gameState.bullets.length - 1; i >= 0; i--) {
        const bullet = gameState.bullets[i];
        bullet.update();

        if (bullet.y < 0 || bullet.y > canvas.height) {
            gameState.bullets.splice(i, 1);
            continue;
        }

        // Collision logic
        if (bullet.isEnemy) {
            if (checkCollision(bullet, gameState.player)) {
                gameState.state = 'gameover';
                document.getElementById('game-over-screen').classList.remove('hidden');
                document.getElementById('final-score').innerText = gameState.score;
                createExplosion(gameState.player.x, gameState.player.y, '#0ff');
                playSound('playerExplosion');
                stopBGM();
                break;
            }
        } else {
            let hit = false;
            for (let j = gameState.invaders.length - 1; j >= 0; j--) {
                const invader = gameState.invaders[j];
                if (checkCollision(bullet, invader)) {
                    gameState.invaders.splice(j, 1);
                    gameState.bullets.splice(i, 1);
                    createExplosion(invader.x, invader.y, '#f0f');
                    playSound('explosion');
                    gameState.score += 100;
                    updateScore();
                    hit = true;
                    
                    // Increase speed slightly per kill
                    gameState.invaderSpeed += 0.02;
                    break;
                }
            }
            if (hit) continue;
        }
    }

    // Update invaders
    let moveDown = false;
    let hitWall = false;

    for (const invader of gameState.invaders) {
        if (invader.x + invader.width/2 > canvas.width - 20 || invader.x - invader.width/2 < 20) {
            hitWall = true;
            break;
        }
    }

    if (hitWall) {
        gameState.invaderDirection *= -1;
        moveDown = true;
    }

    for (const invader of gameState.invaders) {
        invader.x += gameState.invaderSpeed * gameState.invaderDirection;
        if (moveDown) {
            invader.y += 30;
        }

        // Random shooting (more likely with fewer invaders / higher level)
        let fireChance = 0.0005 * gameState.level + (0.01 / gameState.invaders.length);
        if (Math.random() < fireChance) {
            gameState.bullets.push(new Bullet(invader.x, invader.y + invader.height/2, true));
            playSound('enemyShoot');
        }

        // Reach bottom
        if (invader.y + invader.height/2 > gameState.player.y - gameState.player.height/2) {
            gameState.state = 'gameover';
            document.getElementById('game-over-screen').classList.remove('hidden');
            document.getElementById('final-score').innerText = gameState.score;
            createExplosion(gameState.player.x, gameState.player.y, '#0ff');
            playSound('playerExplosion');
            stopBGM();
        }
    }

    // Level clear
    if (gameState.invaders.length === 0) {
         gameState.level++;
         gameState.invaderSpeed = 1 + (gameState.level * 0.2);
         spawnInvaders(gameState.level);
    }
}

function draw() {
    // Clear with dark blue gradient background (simulated via fillRect since clearRect removes gradient)
    ctx.fillStyle = '#050510';
    ctx.fillRect(0, 0, canvas.width, canvas.height);

    // Draw stars
    ctx.fillStyle = '#fff';
    gameState.stars.forEach(star => {
        ctx.globalAlpha = Math.random() * 0.5 + 0.5;
        ctx.beginPath();
        ctx.arc(star.x, star.y, star.size, 0, Math.PI * 2);
        ctx.fill();
    });
    ctx.globalAlpha = 1.0;

    if (gameState.state === 'playing') {
        gameState.player.draw(ctx);
        gameState.invaders.forEach(i => i.draw(ctx));
    }
    
    // Draw bullets and particles in all states if they exist
    gameState.bullets.forEach(b => b.draw(ctx));
    gameState.particles.forEach(p => p.draw(ctx));
}

let lastTime = 0;
function gameLoop(time) {
    // Basic throttle to roughly 60fps logic
    // const deltaTime = time - lastTime;
    // lastTime = time;
    
    if (bgmPlaying) {
        scheduleNote();
    }
    
    update();
    draw();
    requestAnimationFrame(gameLoop);
}

document.getElementById('start-screen').addEventListener('click', () => {
    playSound('start');
    document.getElementById('start-screen').classList.add('hidden');
    initGame();
    gameState.state = 'playing';
    startBGM();
});

document.getElementById('game-over-screen').addEventListener('click', () => {
    playSound('start');
    document.getElementById('game-over-screen').classList.add('hidden');
    initGame();
    gameState.state = 'playing';
    startBGM();
});

// Start loop
requestAnimationFrame(gameLoop);
