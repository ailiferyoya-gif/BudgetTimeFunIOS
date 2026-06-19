const catalog = {
  relax: [
    ["喫茶店と散歩", "近くで一息ついてから軽く歩く", 1400, 110, ["休憩", "会話", "雨でも可"]],
    ["温浴施設で回復", "移動少なめで疲れを落とす", 2600, 180, ["回復", "ひとり向き", "屋内"]]
  ],
  active: [
    ["街歩きミッション", "現在地から3スポットを巡る", 900, 120, ["徒歩", "写真", "軽運動"]],
    ["ボウリング短期戦", "2ゲームだけ遊んで切り上げる", 2200, 100, ["屋内", "友人向き", "短時間"]]
  ],
  culture: [
    ["小さな展示巡り", "美術館、資料館、ギャラリーを優先", 1800, 150, ["展示", "静か", "発見"]],
    ["ローカル書店探索", "近くで本と雑貨を探す", 2500, 90, ["本", "屋内", "少額"]]
  ],
  food: [
    ["食べ歩き2軒", "軽い店を2つ選んで満足度を上げる", 2800, 120, ["食事", "散歩", "満足"]],
    ["市場か地下街ランチ", "迷う楽しさ込みの食事プラン", 1800, 80, ["ランチ", "短時間", "雨でも可"]]
  ]
};

let mood = "relax";

const locationInput = document.querySelector("#location");
const budgetInput = document.querySelector("#budget");
const hoursInput = document.querySelector("#hours");
const budgetValue = document.querySelector("#budgetValue");
const hoursValue = document.querySelector("#hoursValue");
const cards = document.querySelector("#cards");
const count = document.querySelector("#count");

document.querySelectorAll(".moods button").forEach((button) => {
  button.addEventListener("click", () => {
    mood = button.dataset.mood;
    document.querySelectorAll(".moods button").forEach((item) => item.classList.toggle("active", item === button));
    render();
  });
});

[locationInput, budgetInput, hoursInput].forEach((input) => input.addEventListener("input", render));

function render() {
  const budget = Number(budgetInput.value);
  const hours = Number(hoursInput.value);
  const maxMinutes = hours * 60;
  const location = locationInput.value || "現在地";
  budgetValue.textContent = `${budget.toLocaleString("ja-JP")}円`;
  hoursValue.textContent = `${hours}時間`;

  let ideas = catalog[mood]
    .map(([title, subtitle, cost, minutes, tags]) => ({ title, subtitle, cost, minutes, tags }))
    .filter((idea) => idea.cost <= budget && idea.minutes <= maxMinutes);

  if (ideas.length === 0) {
    ideas = [{
      title: "近場の低予算リセット",
      subtitle: `${location}周辺を短時間で楽しむ控えめプラン`,
      cost: Math.min(budget, 800),
      minutes: Math.min(maxMinutes, 60),
      tags: ["低予算", "徒歩", "短時間"]
    }];
  }

  count.textContent = `${ideas.length}件`;
  cards.innerHTML = ideas.map((idea) => `
    <article class="card">
      <h2>${idea.title}</h2>
      <p>${location}：${idea.subtitle}</p>
      <div class="meta">
        <span class="pill">${idea.cost.toLocaleString("ja-JP")}円</span>
        <span class="pill">${idea.minutes}分</span>
      </div>
      <div class="tags">${idea.tags.map((tag) => `<span class="pill">${tag}</span>`).join("")}</div>
    </article>
  `).join("");
}

render();
