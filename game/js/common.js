// --- Player Setup Logic ---

function loadPlayerSetup() {
    const players = JSON.parse(sessionStorage.getItem('players') || '[]');
    const container = document.getElementById('players');
    if (!container) return;

    container.innerHTML = '';

    if (players.length === 0) {
        // Add two empty rows by default if no players exist
        addPlayerRow(0);
        addPlayerRow(1);
    } else {
        players.forEach((player, index) => {
            addPlayerRow(index, player.name, player.gender);
        });
    }
}

function addPlayer() {
    const container = document.getElementById('players');
    const index = container.children.length;
    addPlayerRow(index);
}

function addPlayerRow(index, name = '', gender = '') {
    const container = document.getElementById('players');
    const row = document.createElement('div');
    row.className = 'playerRow';
    row.id = `playerRow-${index}`;
    row.innerHTML = `
      <input id="name${index}" type="text" placeholder="Player First Name" value="${name}" autocomplete="off" onblur="formatName(this)" />
      <div class="gender-selector">
        <button type="button" class="gender-btn ${gender === 'male' ? 'male-selected' : ''}" id="btn-male-${index}" onclick="selectGender(${index}, 'male')">♂</button>
        <button type="button" class="gender-btn ${gender === 'female' ? 'female-selected' : ''}" id="btn-female-${index}" onclick="selectGender(${index}, 'female')">♀</button>
        <input type="hidden" id="gender${index}" value="${gender}" />
      </div>
      <button class="remove-btn" onclick="removePlayer(${index})">×</button>
    `;
    container.appendChild(row);
}

function formatName(input) {
    let name = input.value.trim();
    if (name) {
        name = name.charAt(0).toUpperCase() + name.slice(1).toLowerCase();
        input.value = name;
    }
}

function removePlayer(index) {
    const row = document.getElementById(`playerRow-${index}`);
    if (row) {
        row.remove();
        reindexRows();
    }
}

function reindexRows() {
    const container = document.getElementById('players');
    Array.from(container.children).forEach((row, newIndex) => {
        row.id = `playerRow-${newIndex}`;

        const nameInput = row.querySelector('input[type="text"]');
        nameInput.id = `name${newIndex}`;
        nameInput.setAttribute('onblur', 'formatName(this)');

        const genderInput = row.querySelector('input[type="hidden"]');
        genderInput.id = `gender${newIndex}`;

        const maleBtn = row.querySelector('.gender-btn:first-child');
        maleBtn.id = `btn-male-${newIndex}`;
        maleBtn.setAttribute('onclick', `selectGender(${newIndex}, 'male')`);

        const femaleBtn = row.querySelector('.gender-btn:nth-child(2)');
        femaleBtn.id = `btn-female-${newIndex}`;
        femaleBtn.setAttribute('onclick', `selectGender(${newIndex}, 'female')`);

        const removeBtn = row.querySelector('.remove-btn');
        removeBtn.setAttribute('onclick', `removePlayer(${newIndex})`);
    });
}

function selectGender(index, gender) {
  const input = document.getElementById(`gender${index}`);
  input.value = gender;

  const maleBtn = document.getElementById(`btn-male-${index}`);
  const femaleBtn = document.getElementById(`btn-female-${index}`);

  maleBtn.classList.remove('male-selected');
  femaleBtn.classList.remove('female-selected');

  if(gender === 'male') {
    maleBtn.classList.add('male-selected');
  } else {
    femaleBtn.classList.add('female-selected');
  }
}

function savePlayers(){
  const container = document.getElementById('players');
  const num = container.children.length;
  const players = [];

  for(let i=0;i<num;i++){
    let nameInput = document.getElementById(`name${i}`);
    formatName(nameInput);

    const name = nameInput.value;
    const gender = (document.getElementById(`gender${i}`).value || '').trim();

    if(name) {
        if (!gender) {
            alert(`Please select gender for player "${name}".`);
            return;
        }
        players.push({name, gender});
    }
  }

  if (players.length < 2) {
      alert("Please add at least 2 players with name and gender.");
      return;
  }

  const maleCount = players.filter(p => p.gender === 'male').length;
  const femaleCount = players.filter(p => p.gender === 'female').length;

  if (maleCount < 1 || femaleCount < 1) {
      alert("There must be at least 1 male and 1 female player.");
      return;
  }

  sessionStorage.setItem('players', JSON.stringify(players));

  // Hide the player input screen specifically
  const playerScreen = document.getElementById('playerScreen');
  if(playerScreen) playerScreen.classList.add('hidden');

  // If there is a specific start function defined (like in bottle spinner), call it
  if (typeof window.onPlayersSaved === 'function') {
      window.onPlayersSaved();
  } else {
      // Default behavior (mostly for strip poker legacy)
      const startScreen = document.getElementById('startScreen');
      if(startScreen) startScreen.classList.remove('hidden');
  }
}


// --- Common Game Logic ---

let currentPlayerIndex = 0;
let currentBase = 1;
let maleIndex = 0, femaleIndex = 0;
let tasksLoaded = false;
let baseTasks = { 1: [], 2: [], 3: [], 4: [] };
let punishments = [];
const baseIcons = {1:"🥳",2:"🤓",3:"🫦",4:"👙"};

// Wake Lock
let wakeLock = null;
async function requestWakeLock() {
  if ('wakeLock' in navigator) {
    try {
      wakeLock = await navigator.wakeLock.request('screen');
    } catch (err) {
      console.error(`${err.name}, ${err.message}`);
    }
  }
}

document.addEventListener('visibilitychange', async () => {
  if (wakeLock !== null && document.visibilityState === 'visible') {
    await requestWakeLock();
  }
});

async function loadTasks() {
    try {
        const [t1, t2, t3, t4, p] = await Promise.all([
            fetch('tasks/Base-1.json').then(r => r.json()),
            fetch('tasks/Base-2.json').then(r => r.json()),
            fetch('tasks/Base-3.json').then(r => r.json()),
            fetch('tasks/Base-4.json').then(r => r.json()),
            fetch('tasks/Punishments.json').then(r => r.json())
        ]);

        // Handle both old (array) and new (object) formats for backward compatibility during migration
        baseTasks[1] = Array.isArray(t1) ? { common: t1, male: [], female: [] } : t1;
        baseTasks[2] = Array.isArray(t2) ? { common: t2, male: [], female: [] } : t2;
        baseTasks[3] = Array.isArray(t3) ? { common: t3, male: [], female: [] } : t3;
        baseTasks[4] = Array.isArray(t4) ? { common: t4, male: [], female: [] } : t4;

        punishments = p;

        tasksLoaded = true;
        console.log("Tasks loaded successfully");

        // If a game is already active (e.g. reload), refresh UI
        if(document.getElementById('gameScreen') && !document.getElementById('gameScreen').classList.contains('hidden')){
             if(typeof nextTask === 'function') nextTask();
        }
    } catch (e) {
        console.error("Failed to load tasks", e);
        const display = document.getElementById('taskDisplay');
        if(display) display.innerText = "Error loading tasks.";
    }
}

function showPunishment(){
  const players = JSON.parse(sessionStorage.getItem('players') || '[]');
  if(!players.length) return;

  // Identify the player who currently has the task (previous index because index advanced)
  const playerIndex = (currentPlayerIndex - 1 + players.length) % players.length;
  const player = players[playerIndex];

  if(punishments.length === 0) {
      const display = document.getElementById('taskDisplay');
      if(display) display.innerText = "No punishments loaded!";
      return;
  }

  const p = punishments[Math.floor(Math.random() * punishments.length)];
  const display = document.getElementById('taskDisplay');

  // Determine name to display (You for bottle spinner, Player Name for others)
  // We check if we are in bottle spinner by looking for the bottle element
  let displayName = player.name;
  if(document.getElementById('bottle')) {
      displayName = "You";
  }

  if(display) {
      display.innerHTML = `
        <div style="display:flex;flex-direction:column;align-items:center;">
          <div class="punishment-badge">PUNISHMENT for ${displayName}</div>
          <div>${p}</div>
        </div>`;
      fitText();

      // Check for timer in punishment text
      checkForTimer(p);
  }
}

function fitText(){
  const display = document.getElementById('taskDisplay');
  if(!display) return;

  display.style.overflowY = 'hidden';
  let fontSize = 2.0;
  display.style.fontSize = fontSize + 'rem';
  while(display.scrollHeight > display.clientHeight && fontSize > 0.8){
    fontSize -= 0.1;
    display.style.fontSize = fontSize + 'rem';
  }
  if(display.scrollHeight > display.clientHeight){
    display.style.overflowY = 'auto';
  }
}

function switchBase(base){
  currentBase = base;
  updateBaseIndicator();
  updateBaseSwitch();

  // Hook for specific games to react to base change
  if (typeof onBaseSwitch === 'function') {
      onBaseSwitch();
  }
}

function updateBaseIndicator(){
  const el = document.getElementById('baseIndicator');
  if(el) {
      el.innerHTML = `<div class="baseBtnTop"><span class="emoji">${baseIcons[currentBase]}</span><span>Base ${currentBase}</span></div>`;
  }
}

function updateBaseSwitch(){
  const switchDiv = document.getElementById('baseSwitch');
  if(!switchDiv) return;

  switchDiv.innerHTML = '';
  [1,2,3,4].forEach(b=>{
    if(b === currentBase) return;
    const btn = document.createElement('button');
    btn.innerHTML = `<span class="emoji">${baseIcons[b]}</span> Base ${b}`;
    btn.onclick = ()=> switchBase(b);
    switchDiv.appendChild(btn);
  });
}

// Helper to get a formatted task string
function generateTaskString() {
    const players = JSON.parse(sessionStorage.getItem('players') || '[]');
    if(!players || players.length === 0) return "No players saved!";

    const baseData = baseTasks[currentBase];
    if(!baseData) return `No tasks for Base ${currentBase}`;

    const currentPlayer = players[currentPlayerIndex];

    // Construct the pool of tasks based on gender
    let taskPool = [...(baseData.common || [])]; // Start with common tasks

    if (currentPlayer.gender === 'male' && baseData.male) {
        taskPool = taskPool.concat(baseData.male);
    } else if (currentPlayer.gender === 'female' && baseData.female) {
        taskPool = taskPool.concat(baseData.female);
    }

    if(taskPool.length === 0) return `No tasks available for ${currentPlayer.gender} in Base ${currentBase}`;

    const task = taskPool[Math.floor(Math.random() * taskPool.length)];

    let taskText = "";

    if (task.includes('{p1}') || task.includes('{p2}')) {
      let partner = null;

      if (currentPlayer.gender === 'male') {
        const females = players.filter(p => p.gender === 'female');
        if (females.length > 0) {
          partner = females[femaleIndex % females.length];
          femaleIndex++;
        }
      } else if (currentPlayer.gender === 'female') {
        const males = players.filter(p => p.gender === 'male');
        if (males.length > 0) {
          partner = males[maleIndex % males.length];
          maleIndex++;
        }
      }

      // Fallback if no opposite gender partner found (e.g. all males)
      if (!partner && players.length > 1) {
           // Pick any other player
           const others = players.filter(p => p !== currentPlayer);
           partner = others[Math.floor(Math.random() * others.length)];
      }

      if (partner) {
        taskText = task
          .replaceAll('{p1}', currentPlayer.name)
          .replaceAll('{p2}', partner.name);
      } else {
        taskText = `(Not enough players) ${task}`;
      }
    } else {
      taskText = `${currentPlayer.name}: ${task}`;
    }

    // Advance player index
    currentPlayerIndex = (currentPlayerIndex + 1) % players.length;

    // Check for timer duration in task text
    checkForTimer(taskText);

    return taskText;
}

// --- Timer Logic ---
let timerInterval = null;

function checkForTimer(taskText) {
    const timerContainer = document.getElementById('timerContainer');
    if (!timerContainer) return;

    // Reset timer UI
    timerContainer.innerHTML = '';
    if (timerInterval) clearInterval(timerInterval);

    // Regex to find patterns like "30 Seconds", "1 Minute", "2 Minutes", "30-seconds", "1-minute"
    // Updated to handle optional hyphen
    const timeRegex = /(\d+)\s*-?\s*(Second|Minute)s?/i;
    const match = taskText.match(timeRegex);

    if (match) {
        let duration = parseInt(match[1], 10);
        const unit = match[2].toLowerCase();

        if (unit.startsWith('minute')) {
            duration *= 60;
        }

        const btn = document.createElement('button');
        btn.id = 'startTimerBtn';
        btn.innerHTML = `⏱️ Start ${duration}s Timer`;
        btn.onclick = () => startTimer(duration);
        timerContainer.appendChild(btn);
    }
}

function startTimer(duration) {
    const timerContainer = document.getElementById('timerContainer');
    timerContainer.innerHTML = `<div id="timerDisplay">${duration}</div>`;

    const display = document.getElementById('timerDisplay');
    let timeLeft = duration;

    if (timerInterval) clearInterval(timerInterval);

    timerInterval = setInterval(() => {
        timeLeft--;
        display.innerText = timeLeft;

        if (timeLeft <= 0) {
            clearInterval(timerInterval);
            display.innerText = "⏰ Time's Up!";
        }
    }, 1000);
}
