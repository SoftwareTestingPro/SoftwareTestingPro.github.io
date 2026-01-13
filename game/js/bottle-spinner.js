// bottle-spinner.js

const bottle = document.getElementById('bottle');
const spinButton = document.getElementById('spin-button');
const taskModal = document.createElement('div');

// Setup Modal for displaying tasks
taskModal.id = 'task-modal';
taskModal.className = 'hidden';
taskModal.innerHTML = `
    <div class="modal-content">
        <div id="baseIndicator" style="margin-bottom:15px;"></div>
        <div id="taskDisplay" style="font-size:1.5rem; font-weight:bold; margin-bottom:20px; text-align:center;"></div>
        <div id="timerContainer"></div>
        <div style="display:flex; gap:10px; justify-content:center;">
            <button id="close-modal-btn" style="background:var(--accent); color:white; padding:10px 20px; border-radius:8px;">Done</button>
            <button id="punishBtn" onclick="showPunishment()" style="background:#ff4757; color:white; padding:10px 20px; border-radius:8px;">Punishment</button>
        </div>
        <div id="baseSwitch" style="margin-top:20px;"></div>
    </div>
`;
document.body.appendChild(taskModal);

// Add styles for modal
const style = document.createElement('style');
style.innerHTML = `
    #task-modal {
        position: fixed; top: 0; left: 0; width: 100%; height: 100%;
        background: rgba(0,0,0,0.85); z-index: 100;
        display: flex; justify-content: center; align-items: center;
        padding: 20px; box-sizing: border-box;
    }
    .modal-content {
        background: linear-gradient(135deg, #4facfe, #00f2fe);
        padding: 30px; border-radius: 20px; width: 100%; max-width: 400px;
        box-shadow: 0 10px 30px rgba(0,0,0,0.5);
        display: flex; flex-direction: column; align-items: center;
    }
    #task-modal.hidden { display: none; }
`;
document.head.appendChild(style);

document.getElementById('close-modal-btn').addEventListener('click', () => {
    taskModal.classList.add('hidden');
    // Stop any running timer when closing modal
    const timerContainer = document.getElementById('timerContainer');
    if(timerContainer) timerContainer.innerHTML = '';
    if(typeof timerInterval !== 'undefined' && timerInterval) clearInterval(timerInterval);
});


let isSpinning = false;

spinButton.addEventListener('click', () => {
    if (isSpinning) return;

    // Ensure tasks are loaded
    if(!tasksLoaded) {
        alert("Tasks are loading...");
        return;
    }

    isSpinning = true;
    spinButton.disabled = true;
    spinButton.innerText = "Spinning...";

    // Random rotation: at least 5 full spins (1800 deg) + random angle
    const randomRotation = Math.floor(Math.random() * 3600) + 1800;

    // Reset transition to allow multiple spins
    bottle.style.transition = 'transform 4s cubic-bezier(0.2, 0.8, 0.3, 1)';
    bottle.style.transform = `rotate(${randomRotation}deg)`;

    setTimeout(() => {
        isSpinning = false;
        spinButton.disabled = false;
        spinButton.innerText = "Spin the Bottle";

        // Show task
        showTask();

        // Reset bottle rotation visually (optional, but keeps numbers small)
        // We do this by disabling transition, resetting to mod 360, then re-enabling
        const actualRotation = randomRotation % 360;
        bottle.style.transition = 'none';
        bottle.style.transform = `rotate(${actualRotation}deg)`;

    }, 4000);
});

function showTask() {
    // Update base indicator in modal
    updateBaseIndicator();
    updateBaseSwitch();

    // Generate and show task
    let taskText = generateTaskString();

    // Replace player name with "You"
    const players = JSON.parse(sessionStorage.getItem('players') || '[]');
    if (players.length > 0) {
        const lastPlayerIndex = (currentPlayerIndex - 1 + players.length) % players.length;
        const lastPlayer = players[lastPlayerIndex];
        taskText = taskText.replace(lastPlayer.name + ':', 'You:');
        taskText = taskText.replaceAll(lastPlayer.name, 'You');
    }

    const display = document.getElementById('taskDisplay');
    if(display) {
        display.innerText = taskText;
    }

    taskModal.classList.remove('hidden');
}

// Hook called by common.js when base is switched
function onBaseSwitch() {
    // If modal is open, refresh the task for the new base
    if (!taskModal.classList.contains('hidden')) {
        showTask();
    }
}

// Called by common.js savePlayers
window.onPlayersSaved = function() {
    document.getElementById('player-setup-container').classList.add('hidden');
    document.getElementById('game-container').classList.remove('hidden');

    // Initialize game state
    currentPlayerIndex = 0;
    currentBase = 1;
    updateBaseIndicator();
    updateBaseSwitch();
    requestWakeLock();
};

// Initialize
(function init(){
  loadTasks();
})();
