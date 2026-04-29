// strip-poker.js

function startGame(){
  if(!tasksLoaded){
    alert("Please wait for tasks to load...");
    return;
  }
  currentPlayerIndex = 0;
  currentBase = 1;
  maleIndex = 0;
  femaleIndex = 0;

  updateBaseIndicator();
  updateBaseSwitch();
  updateCardBaseClass(); // Set initial card color

  document.getElementById('gameScreen').classList.remove('hidden');

  nextTask();
  requestWakeLock();
}

function onHeartClick(){
  const btn = document.getElementById('nextTaskBtn');
  btn.classList.add('pulse-strong');
  setTimeout(()=> btn.classList.remove('pulse-strong'), 520);
  nextTask();
}

function nextTask(){
    // Flip card back to the front
    const cardContainer = document.getElementById('card-container');
    if (cardContainer.classList.contains('flipped')) {
        cardContainer.classList.remove('flipped');
    }

    const taskText = generateTaskString();
    const display = document.getElementById('taskDisplay');
    if(display) {
        display.innerText = taskText;
        fitText(display);
    }
}

// Override the common showPunishment to handle card flip
function showPunishment(){
  const players = JSON.parse(sessionStorage.getItem('players') || '[]');
  if(!players.length) return;

  const playerIndex = (currentPlayerIndex - 1 + players.length) % players.length;
  const player = players[playerIndex];

  if(punishments.length === 0) {
      const display = document.getElementById('punishmentDisplay');
      if(display) display.innerText = "No punishments loaded!";
      return;
  }

  const p = punishments[Math.floor(Math.random() * punishments.length)];
  const display = document.getElementById('punishmentDisplay');
  if(display) {
      display.innerHTML = `
        <div class="punishment-badge">PUNISHMENT for ${player.name}</div>
        <div>${p}</div>`;
      fitText(display);

      // Flip the card
      document.getElementById('card-container').classList.add('flipped');

      // Check for timer in punishment text
      checkForTimer(p);
  }
}

// Override fitText to work with both displays
function fitText(element){
  if(!element) return;

  element.style.overflowY = 'hidden';
  let fontSize = 1.8; // Start with a slightly smaller size for justified text
  element.style.fontSize = fontSize + 'rem';
  while(element.scrollHeight > element.clientHeight && fontSize > 0.8){
    fontSize -= 0.1;
    element.style.fontSize = fontSize + 'rem';
  }
  if(element.scrollHeight > element.clientHeight){
    element.style.overflowY = 'auto';
  }
}

function updateCardBaseClass() {
    const cardFront = document.querySelector('.card-front');
    if(cardFront) {
        cardFront.classList.remove('base-1-bg', 'base-2-bg', 'base-3-bg', 'base-4-bg');
        cardFront.classList.add(`base-${currentBase}-bg`);
    }
}

// Hook called by common.js when base is switched
function onBaseSwitch() {
    updateCardBaseClass();
    nextTask();
}

// Called by common.js savePlayers
window.onPlayersSaved = function() {
    document.getElementById('player-setup-container').classList.add('hidden');
    startGame();
};

// Initialize
(function init(){
  loadTasks();
  // Player setup is loaded via HTML script tag calling loadPlayerSetup()
})();