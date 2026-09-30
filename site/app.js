const reducedMotion = matchMedia('(prefers-reduced-motion: reduce)');
const motionToggle = document.getElementById('motion-toggle');
let paused = reducedMotion.matches;
const cycles = [];
function updateMotion() {
  document.documentElement.classList.toggle('motion-paused', paused || document.hidden);
  motionToggle.textContent = paused ? 'Enable motion' : 'Pause motion';
  motionToggle.setAttribute('aria-pressed', String(paused));
}
motionToggle.addEventListener('click', () => { paused = !paused; updateMotion(); });
reducedMotion.addEventListener('change', () => { paused = reducedMotion.matches; updateMotion(); });
document.addEventListener('visibilitychange', updateMotion);
updateMotion();

function animateImage(image) {
  if (paused || reducedMotion.matches) return;
  image.getAnimations().forEach(animation => animation.cancel());
  image.animate([{ opacity: .35, transform: 'translateY(6px)' }, { opacity: 1, transform: 'translateY(0)' }], { duration: 550, easing: 'ease-out' });
}
function cycle(element, duration, render) {
  const state = { element, duration, elapsed: 0, visible: false, holdUntil: 0, render };
  cycles.push(state);
  render(0);
  return state;
}
const steps = [
  ['01 / HOLD', 'A shortcut for<br>your train of thought.', 'Hold Right Option to start a dictation.', 'Right ⌥'],
  ['02 / SPEAK', 'Let the<br>thought out.', '“More time making things.”', 'Listening…'],
  ['03 / RELEASE', 'Your words.<br>Right where you need them.', 'Release the key. The final transcript is inserted at your cursor.', 'Release ⌥']
];
const demo = document.getElementById('walkthrough');
let lastStep = -1;
cycle(demo, 10500, elapsed => {
  const index = elapsed < 2300 ? 0 : elapsed < 6500 ? 1 : 2;
  if (index !== lastStep) {
    lastStep = index;
    demo.dataset.step = String(index);
    const [count, title, description, key] = steps[index];
    document.getElementById('demo-count').textContent = count;
    document.getElementById('demo-title').innerHTML = title;
    document.getElementById('demo-description').textContent = description;
    document.getElementById('demo-key').textContent = key;
  }
  demo.style.setProperty('--progress', `${elapsed / 105}%`);
});
const styleDescriptions = {
  galley: 'Galley — the compact everyday bar.',
  column: 'Column — room for your train of thought.',
  ticker: 'Ticker — one quiet line along the edge of your screen.',
  proof: 'Proof — words set on a small editorial sheet.'
};
const views = {
  home: 'Home — ready for your next thought.',
  history: 'History — find, copy, and revisit your words.',
  insights: 'Insights — a look at your local dictation habits.',
  dictionary: 'Dictionary — the names and terms you use, spelled your way.',
  snippets: 'Snippets — a short phrase becomes a longer thought.',
  settings: 'Settings — your model, shortcuts, and floating overlay.'
};
function createGallery(element, attribute, descriptions, imageID, captionID, seconds) {
  const keys = Object.keys(descriptions);
  const buttons = [...element.querySelectorAll(`[${attribute}]`)];
  const image = document.getElementById(imageID);
  let current = -1;
  const state = cycle(element, seconds * 1000 * keys.length, elapsed => {
    const index = Math.floor(elapsed / (seconds * 1000));
    element.style.setProperty('--progress', `${(elapsed % (seconds * 1000)) / (seconds * 10)}%`);
    if (index === current) return;
    current = index;
    const key = keys[index];
    buttons.forEach(button => {
      const selected = button.getAttribute(attribute) === key;
      button.classList.toggle('active', selected);
      button.setAttribute('aria-pressed', String(selected));
    });
    image.src = `assets/screenshots/${attribute === 'data-style' ? 'overlay-' : ''}${key}.png`;
    image.alt = `${descriptions[key]} Actual interface with fictional sample content.`;
    document.getElementById(captionID).textContent = descriptions[key];
    if (attribute === 'data-view') document.getElementById('tour-counter').textContent = `0${index + 1} / 06`;
    animateImage(image);
  });
  buttons.forEach(button => button.addEventListener('click', () => {
    state.elapsed = keys.indexOf(button.getAttribute(attribute)) * seconds * 1000;
    state.holdUntil = performance.now() + 10000;
    state.render(state.elapsed);
  }));
}
createGallery(document.querySelector('.overlay-section'), 'data-style', styleDescriptions, 'style-image', 'style-description', 4.5);
createGallery(document.getElementById('app-tour'), 'data-view', views, 'tour-image', 'tour-description', 5.5);

const observer = new IntersectionObserver(entries => {
  entries.forEach(entry => {
    entry.target.classList.toggle('in-view', entry.isIntersecting);
    const state = cycles.find(item => item.element === entry.target);
    if (state) state.visible = entry.isIntersecting;
  });
}, { threshold: .12 });
cycles.forEach(state => observer.observe(state.element));
document.querySelectorAll('.hero-visual, .steps, .screen-card').forEach(element => observer.observe(element));
let previous = performance.now();
setInterval(() => {
  const now = performance.now();
  const delta = Math.min(now - previous, 250);
  previous = now;
  if (paused || document.hidden) return;
  cycles.forEach(state => {
    if (!state.visible || now < state.holdUntil || state.element.matches(':focus-within')) return;
    state.elapsed = (state.elapsed + delta) % state.duration;
    state.render(state.elapsed);
  });
}, 100);
