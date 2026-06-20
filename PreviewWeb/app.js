const fallbackCatalog = {
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

const overpassQueries = {
  relax: 'node(around:1800,{lat},{lon})[amenity~"cafe|public_bath"];node(around:1800,{lat},{lon})[leisure="park"];',
  active: 'node(around:2200,{lat},{lon})[leisure~"park|bowling_alley|sports_centre"];node(around:2200,{lat},{lon})[tourism="attraction"];',
  culture: 'node(around:2200,{lat},{lon})[tourism~"museum|gallery"];node(around:2200,{lat},{lon})[shop~"books|stationery"];',
  food: 'node(around:1800,{lat},{lon})[amenity~"restaurant|cafe|fast_food"];node(around:1800,{lat},{lon})[shop~"bakery|convenience"];'
};

const moodCosts = { relax: 1400, active: 1200, culture: 1600, food: 2200 };
const moodMinutes = { relax: 110, active: 120, culture: 100, food: 90 };
const moodLabels = { relax: "ゆっくり", active: "動きたい", culture: "発見したい", food: "食べたい" };

let mood = "relax";
let coords = null;
let places = [];
let placesMood = null;
let isSearching = false;
let searchRequestId = 0;

const locationInput = document.querySelector("#location");
const budgetInput = document.querySelector("#budget");
const hoursInput = document.querySelector("#hours");
const budgetValue = document.querySelector("#budgetValue");
const hoursValue = document.querySelector("#hoursValue");
const cards = document.querySelector("#cards");
const count = document.querySelector("#count");
const locationStatus = document.querySelector("#locationStatus");
const useLocationButton = document.querySelector("#useLocation");

document.querySelectorAll(".moods button").forEach((button) => {
  button.addEventListener("click", async () => {
    const nextMood = button.dataset.mood;
    if (nextMood === mood) {
      return;
    }

    mood = nextMood;
    places = [];
    placesMood = null;
    document.querySelectorAll(".moods button").forEach((item) => item.classList.toggle("active", item === button));
    render();
    searchNearby();
  });
});

[locationInput, budgetInput, hoursInput].forEach((input) => input.addEventListener("input", render));

useLocationButton.addEventListener("click", () => {
  if (!navigator.geolocation) {
    locationStatus.textContent = "このブラウザでは現在地取得を利用できません。";
    return;
  }

  useLocationButton.disabled = true;
  locationStatus.textContent = "現在地を取得しています...";
  navigator.geolocation.getCurrentPosition(async (position) => {
    coords = {
      lat: position.coords.latitude,
      lon: position.coords.longitude
    };
    locationInput.value = "現在地周辺";
    locationStatus.textContent = `現在地を取得しました (${coords.lat.toFixed(4)}, ${coords.lon.toFixed(4)})`;
    useLocationButton.disabled = false;
    searchNearby();
    render();
  }, (error) => {
    locationStatus.textContent = `現在地を取得できませんでした: ${error.message}`;
    useLocationButton.disabled = false;
    render();
  }, {
    enableHighAccuracy: false,
    timeout: 10000,
    maximumAge: 300000
  });
});

async function searchNearby() {
  if (!coords) {
    places = [];
    placesMood = null;
    return;
  }

  const requestId = ++searchRequestId;
  const requestMood = mood;
  const requestCoords = { ...coords };
  isSearching = true;
  render();

  try {
    const body = `[out:json][timeout:12];(${overpassQueries[requestMood].replaceAll("{lat}", requestCoords.lat).replaceAll("{lon}", requestCoords.lon)});out center 12;`;
    const response = await fetch("https://overpass-api.de/api/interpreter", {
      method: "POST",
      headers: { "Content-Type": "text/plain;charset=UTF-8" },
      body
    });

    if (!response.ok) {
      throw new Error(`HTTP ${response.status}`);
    }

    const data = await response.json();
    if (requestId !== searchRequestId || requestMood !== mood) {
      return;
    }

    places = data.elements
      .filter((item) => item.tags && item.tags.name)
      .map((item) => {
        const lat = item.lat ?? item.center?.lat;
        const lon = item.lon ?? item.center?.lon;
        return {
          name: item.tags.name,
          lat,
          lon,
          distance: lat && lon ? distanceMeters(requestCoords.lat, requestCoords.lon, lat, lon) : null,
          address: [item.tags["addr:city"], item.tags["addr:street"], item.tags["addr:housenumber"]].filter(Boolean).join(" ")
        };
      })
      .filter((item) => item.lat && item.lon)
      .sort((a, b) => (a.distance ?? 999999) - (b.distance ?? 999999))
      .slice(0, 6);
    placesMood = requestMood;
  } catch (error) {
    if (requestId !== searchRequestId || requestMood !== mood) {
      return;
    }

    locationStatus.textContent = "周辺検索に失敗しました。固定プランを表示しています。";
    places = [];
    placesMood = null;
  } finally {
    if (requestId === searchRequestId) {
      isSearching = false;
      render();
    }
  }
}

function render() {
  const budget = Number(budgetInput.value);
  const hours = Number(hoursInput.value);
  const maxMinutes = hours * 60;
  const location = locationInput.value || "現在地";
  budgetValue.textContent = `${budget.toLocaleString("ja-JP")}円`;
  hoursValue.textContent = `${hours}時間`;

  const activePlaces = placesMood === mood ? places : [];
  let ideas = activePlaces.length ? activePlaces.map((place) => placeIdea(place, budget, maxMinutes, placesMood)) : fallbackIdeas(location, budget, maxMinutes);
  ideas = ideas.filter((idea) => idea.cost <= budget && idea.minutes <= maxMinutes);

  if (ideas.length === 0) {
    ideas = [{
      title: "近場の低予算リセット",
      subtitle: `${location}周辺を短時間で楽しむ控えめプラン`,
      cost: Math.min(budget, 800),
      minutes: Math.min(maxMinutes, 60),
      tags: ["低予算", "徒歩", "短時間"],
      place: null
    }];
  }

  count.textContent = isSearching ? "検索中" : `${ideas.length}件`;
  cards.innerHTML = ideas.map((idea) => `
    <article class="card">
      <h2>${escapeHtml(idea.title)}</h2>
      <p>${escapeHtml(idea.subtitle)}</p>
      <div class="meta">
        <span class="pill">${idea.cost.toLocaleString("ja-JP")}円</span>
        <span class="pill">${idea.minutes}分</span>
        ${idea.place?.distance ? `<span class="pill">${formatDistance(idea.place.distance)}</span>` : ""}
      </div>
      ${idea.place ? `<p class="place">${escapeHtml(idea.place.address || "現在地周辺")}<br><a href="https://www.google.com/maps/search/?api=1&query=${idea.place.lat},${idea.place.lon}" target="_blank" rel="noreferrer">地図で開く</a></p>` : ""}
      <div class="tags">${idea.tags.map((tag) => `<span class="pill">${escapeHtml(tag)}</span>`).join("")}</div>
    </article>
  `).join("");
}

function fallbackIdeas(location, budget, maxMinutes) {
  return fallbackCatalog[mood]
    .map(([title, subtitle, cost, minutes, tags]) => ({ title, subtitle: `${location}：${subtitle}`, cost, minutes, tags, place: null }))
    .filter((idea) => idea.cost <= budget && idea.minutes <= maxMinutes);
}

function placeIdea(place, budget, maxMinutes, ideaMood) {
  const travelMinutes = Math.max(20, Math.round((place.distance ?? 600) / 70) + 35);
  const minutes = Math.min(maxMinutes, Math.max(moodMinutes[ideaMood], travelMinutes));
  return {
    title: `${place.name}へ行く`,
    subtitle: `${moodLabels[ideaMood]}目的で、現在地から行ける場所として表示しています。`,
    cost: Math.min(budget, moodCosts[ideaMood]),
    minutes,
    tags: ["現在地から検索", moodLabels[ideaMood], "地図表示"],
    place
  };
}

function distanceMeters(lat1, lon1, lat2, lon2) {
  const radius = 6371000;
  const toRad = (value) => value * Math.PI / 180;
  const dLat = toRad(lat2 - lat1);
  const dLon = toRad(lon2 - lon1);
  const a = Math.sin(dLat / 2) ** 2 + Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLon / 2) ** 2;
  return radius * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

function formatDistance(meters) {
  return meters >= 1000 ? `${(meters / 1000).toFixed(1)}km` : `${Math.round(meters)}m`;
}

function escapeHtml(value) {
  return String(value).replace(/[&<>"']/g, (char) => ({
    "&": "&amp;",
    "<": "&lt;",
    ">": "&gt;",
    "\"": "&quot;",
    "'": "&#039;"
  }[char]));
}

render();
