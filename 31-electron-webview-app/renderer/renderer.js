const input = document.querySelector("#input");
const output = document.querySelector("#output");

function update() {
  output.value = `${input.value} -> ${window.victim.hash(input.value)}`;
}

document.querySelector("#hash").addEventListener("click", update);
update();
