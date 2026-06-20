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

const transitQuery = 'node(around:2600,{lat},{lon})[railway~"station|halt|tram_stop"];node(around:2600,{lat},{lon})[highway="bus_stop"];node(around:2600,{lat},{lon})[public_transport~"station|stop_position|platform"];';
const moodCosts = { relax: 1400, active: 1200, culture: 1600, food: 2200 };
const moodMinutes = { relax: 110, active: 120, culture: 100, food: 90 };
const moodLabels = { relax: "ゆっくり", active: "動きたい", culture: "発見したい", food: "食べたい" };
const travelLabels = { walk: "徒歩", transit: "公共交通" };

let mood = "relax";
let travelMode = "walk";
let coords = null;
let places = [];
let placesMood = null;
let placesTravelMode = null;
let isSearching = false;
let searchRequestId = 0;
let map = null;
let mapMarkers = [];

const locationInput = document.querySelector("#location");
const budgetInput = document.querySelector("#budget");
const hoursInput = document.querySelector("#hours");
const budgetValue = document.querySelector("#budgetValue");
const hoursValue = document.querySelector("#hoursValue");
const cards = document.querySelector("#cards");
const count = document.querySelector("#count");
const locationStatus = document.querySelector("#locationStatus");
const useLocationButton = document.querySelector("#useLocation");
const mapStatus = document.querySelector("#mapStatus");

document.querySelectorAll(".moods button").forEach((button) => {
  button.addEventListener("click", async () => {
    const nextMood = button.dataset.mood;
    if (nextMood === mood) {
      return;
    }

    mood = nextMood;
    places = [];
    placesMood = null;
    placesTravelMode = null;
    document.querySelectorAll(".moods button").forEach((item) => item.classList.toggle("active", item === button));
    render();
    searchNearby();
  });
});

document.querySelectorAll(".travel-modes button").forEach((button) => {
  button.addEventListener("click", () => {
    const nextMode = button.dataset.travel;
    if (nextMode === travelMode) {
      return;
    }

    travelMode = nextMode;
    places = [];
    placesMood = null;
    placesTravelMode = null;
    document.querySelectorAll(".travel-modes button").forEach((item) => item.classList.toggle("active", item === button));
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
    placesTravelMode = null;
    return;
  }

  const requestId = ++searchRequestId;
  const requestMood = mood;
  const requestTravelMode = travelMode;
  const requestCoords = { ...coords };
  isSearching = true;
  render();

  try {
    const queryParts = [
      overpassQueries[requestMood],
      requestTravelMode === "transit" ? transitQuery : ""
    ].join("");
    const body = `[out:json][timeout:12];(${queryParts.replaceAll("{lat}", requestCoords.lat).replaceAll("{lon}", requestCoords.lon)});out center 16;`;
    const response = await fetch("https://overpass-api.de/api/interpreter", {
      method: "POST",
      headers: { "Content-Type": "text/plain;charset=UTF-8" },
      body
    });

    if (!response.ok) {
      throw new Error(`HTTP ${response.status}`);
    }

    const data = await response.json();
    if (requestId !== searchRequestId || requestMood !== mood || requestTravelMode !== travelMode) {
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
          kind: placeKind(item.tags),
          address: [item.tags["addr:city"], item.tags["addr:street"], item.tags["addr:housenumber"]].filter(Boolean).join(" ")
        };
      })
      .filter((item) => item.lat && item.lon)
      .sort((a, b) => (a.distance ?? 999999) - (b.distance ?? 999999))
      .slice(0, 6);
    placesMood = requestMood;
    placesTravelMode = requestTravelMode;
  } catch (error) {
    if (requestId !== searchRequestId || requestMood !== mood || requestTravelMode !== travelMode) {
      return;
    }

    locationStatus.textContent = "周辺検索に失敗しました。固定プランを表示しています。";
    places = [];
    placesMood = null;
    placesTravelMode = null;
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

  const activePlaces = placesMood === mood && placesTravelMode === travelMode ? places : [];
  let ideas = activePlaces.length ? activePlaces.map((place) => placeIdea(place, budget, maxMinutes, placesMood, placesTravelMode)) : fallbackIdeas(location, budget, maxMinutes);
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
        <span class="pill">${travelLabels[travelMode]}</span>
        ${idea.place?.distance ? `<span class="pill">${formatDistance(idea.place.distance)}</span>` : ""}
      </div>
      ${idea.place ? `<p class="place">${escapeHtml([idea.place.kind, idea.place.address || "現在地周辺"].filter(Boolean).join(" / "))}</p>
      <div class="route-links">
        <a href="${routeUrl(idea.place, "walk")}" target="_blank" rel="noreferrer">徒歩ルート</a>
        <a href="${routeUrl(idea.place, "transit")}" target="_blank" rel="noreferrer">公共交通ルート</a>
      </div>` : ""}
      <div class="tags">${idea.tags.map((tag) => `<span class="pill">${escapeHtml(tag)}</span>`).join("")}</div>
    </article>
  `).join("");
  updateMap(ideas);
}

function fallbackIdeas(location, budget, maxMinutes) {
  return fallbackCatalog[mood]
    .map(([title, subtitle, cost, minutes, tags]) => ({ title, subtitle: `${location}：${subtitle}`, cost, minutes, tags, place: null }))
    .filter((idea) => idea.cost <= budget && idea.minutes <= maxMinutes);
}

function placeIdea(place, budget, maxMinutes, ideaMood, ideaTravelMode) {
  const travelMinutes = Math.max(20, Math.round((place.distance ?? 600) / 70) + 35);
  const modeExtra = ideaTravelMode === "transit" ? 18 : 0;
  const minutes = Math.min(maxMinutes, Math.max(moodMinutes[ideaMood], travelMinutes + modeExtra));
  return {
    title: `${place.name}へ行く`,
    subtitle: `${moodLabels[ideaMood]}目的で、${travelLabels[ideaTravelMode]}でも行きやすい場所として表示しています。`,
    cost: Math.min(budget, moodCosts[ideaMood] + (ideaTravelMode === "transit" ? 420 : 0)),
    minutes,
    tags: ["現在地から検索", moodLabels[ideaMood], travelLabels[ideaTravelMode], "地図表示"],
    place
  };
}

function initMap() {
  if (map || !window.L) {
    return;
  }

  map = L.map("map", { zoomControl: true }).setView([35.6812, 139.7671], 12);
  L.tileLayer("https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png", {
    maxZoom: 19,
    attribution: "&copy; OpenStreetMap contributors"
  }).addTo(map);
}

function updateMap(ideas) {
  initMap();
  if (!map) {
    return;
  }

  mapMarkers.forEach((marker) => marker.remove());
  mapMarkers = [];

  if (coords) {
    mapMarkers.push(L.marker([coords.lat, coords.lon]).addTo(map).bindPopup("現在地"));
  }

  ideas
    .filter((idea) => idea.place)
    .forEach((idea) => {
      const marker = L.marker([idea.place.lat, idea.place.lon])
        .addTo(map)
        .bindPopup(`<strong>${escapeHtml(idea.place.name)}</strong><br>${escapeHtml(idea.place.kind || "候補地")}`);
      mapMarkers.push(marker);
    });

  if (mapMarkers.length > 1) {
    const group = L.featureGroup(mapMarkers);
    map.fitBounds(group.getBounds().pad(0.18));
    mapStatus.textContent = `${mapMarkers.length - (coords ? 1 : 0)}件を地図表示`;
  } else if (coords) {
    map.setView([coords.lat, coords.lon], 14);
    mapStatus.textContent = "現在地を表示";
  } else {
    mapStatus.textContent = "現在地未取得";
  }
}

function routeUrl(place, mode) {
  const origin = coords ? `${coords.lat},${coords.lon}` : "";
  const destination = `${place.lat},${place.lon}`;
  const travelmode = mode === "transit" ? "transit" : "walking";
  return `https://www.google.com/maps/dir/?api=1&origin=${encodeURIComponent(origin)}&destination=${encodeURIComponent(destination)}&travelmode=${travelmode}`;
}

function placeKind(tags) {
  if (tags.railway || tags.public_transport || tags.highway === "bus_stop") return "駅・バス停";
  if (tags.amenity === "restaurant" || tags.amenity === "cafe" || tags.shop === "bakery") return "飲食";
  if (tags.tourism === "museum" || tags.tourism === "gallery" || tags.shop === "books") return "文化";
  if (tags.leisure) return "屋外・運動";
  return "候補地";
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
initMap();
