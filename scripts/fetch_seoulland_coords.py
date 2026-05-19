import requests
import json

query = """
[out:json][timeout:25];
(
  node(37.424,126.975,37.432,126.983);
  way(37.424,126.975,37.432,126.983);
);
out body;
"""

response = requests.get(
    "https://overpass-api.de/api/interpreter",
    params={"data": query}
)

data = response.json()

results = []
for element in data["elements"]:
    tags = element.get("tags", {})
    name = tags.get("name:ko") or tags.get("name")
    if not name:
        continue
    if element["type"] == "node":
        lat = element["lat"]
        lng = element["lon"]
    elif element["type"] == "way":
        lat = element.get("center", {}).get("lat")
        lng = element.get("center", {}).get("lon")
    if lat and lng:
        results.append({"name": name, "lat": lat, "lng": lng})

for r in results:
    print(f"name: {r['name']}, lat: {r['lat']}, lng: {r['lng']}")
