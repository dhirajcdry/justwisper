const styleDescriptions = {
  galley: 'Galley — the compact everyday bar.',
  column: 'Column — a little room for your train of thought.',
  ticker: 'Ticker — one quiet line along the edge of your screen.',
  proof: 'Proof — words set on a small editorial sheet.'
};
for (const button of document.querySelectorAll('[data-style]')) {
  button.addEventListener('click', () => {
    const style = button.dataset.style;
    for (const option of document.querySelectorAll('[data-style]')) {
      const selected = option === button;
      option.classList.toggle('active', selected);
      option.setAttribute('aria-pressed', String(selected));
    }
    const image = document.getElementById('style-image');
    image.src = `assets/screenshots/overlay-${style}.png`;
    image.alt = `${styleDescriptions[style]} Actual interface with sample text.`;
    document.getElementById('style-description').textContent = styleDescriptions[style];
  });
}
const demo = document.getElementById('walkthrough');
const play = document.getElementById('play-demo');
const steps = [
  ['01 / HOLD', 'A shortcut for<br>your train of thought.', 'Hold Right Option to start a dictation.', 'Right ⌥'],
  ['02 / SPEAK', 'Let the<br>thought out.', '“Less time typing. More time making things.”', 'Listening…'],
  ['03 / RELEASE', 'Your words.<br>Right where you need them.', 'Release the key. The final transcript is inserted at your cursor.', 'Release ⌥']
];
let timer;
let playing = false;
let currentStep = 0;
function showStep(index) {
  currentStep = index;
  demo.dataset.step = String(index);
  const [count, title, description, key] = steps[index];
  document.getElementById('demo-count').textContent = count;
  document.getElementById('demo-title').innerHTML = title;
  document.getElementById('demo-description').textContent = description;
  document.getElementById('demo-key').textContent = key;
}
play.addEventListener('click', () => {
  if (playing) {
    clearInterval(timer);
    playing = false;
    play.textContent = '▶ Replay walkthrough';
    return;
  }
  playing = true;
  showStep(0);
  play.textContent = 'Ⅱ Pause walkthrough';
  timer = setInterval(() => {
    if (currentStep === 2) {
      clearInterval(timer);
      playing = false;
      play.textContent = '↻ Replay walkthrough';
      return;
    }
    showStep(currentStep + 1);
  }, 3000);
});
