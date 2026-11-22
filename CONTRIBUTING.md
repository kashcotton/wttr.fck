# Add your own roasts

Every insult, pundit argument and election joke in wttr.fck lives in plain
JSON files in [`content/`](content/). When your pull request is merged, the
app downloads it automatically. Nobody has to update anything, and your
GitHub name shows up next to your line in the app.

## The 60-second version

1. Open a file in [`content/voices/`](content/voices/), for example `classic.json`.
2. Click the pencil icon to edit it on GitHub.
3. Add a line under the weather it's about:

   ```json
   "rain": [
     { "head": "It's raining. Shocking.", "sub": "Bring an umbrella, genius.", "by": "your-github-name" }
   ]
   ```
4. Click **Propose changes**, then **Create pull request**.

Don't want to touch JSON? [Open a "Submit a roast" issue](../../issues/new?template=roast.yml)
and someone will add it for you.

## The format

Each line has a **head** (the big punchline, max 80 characters) and a
**sub** (the follow-up, max 180). `by` is optional: your GitHub username,
without the `@`.

### Weather moods

| Mood | When it shows up |
|---|---|
| `storm` | Thunderstorms |
| `snow` | Snow, sleet, snow showers |
| `rain` | Rain and showers |
| `drizzle` | Light drizzle |
| `fog` | Fog |
| `windy` | Gusts over ~55 km/h (35 mph) |
| `scorching` | Feels like 35°C / 95°F or hotter |
| `hot` | Feels like 28–35°C / 82–95°F |
| `freezing` | Feels like below 0°C / 32°F |
| `cold` | Feels like 0–11°C / 32–52°F |
| `nice` | Clear or partly cloudy, pleasant, daytime |
| `meh` | Gray, cloudy, unremarkable |
| `clearNight` | Clear skies at night |

### Placeholders

These get replaced with real numbers, in the user's own units:

`{temp}` `{feels}` `{high}` `{low}` `{wind}` `{gusts}` `{pop}` (chance of rain, as a number) `{city}` `{uv}` `{vis}`

### Swearing

Write it as filthy as you like. The app has three language levels and the
**Clean** setting automatically swaps words (fuck → fudge, shit → crud, etc.).
If you use a swear word the filter doesn't know, the tests will fail and
tell you to add it to [`lib/roasts/censor.dart`](lib/roasts/censor.dart).

### Making a whole new voice

Copy any file in `content/voices/`, change the `id`, `name` and
`description`, then add the file path to [`content/index.json`](content/index.json).
You don't need lines for every mood: anything missing falls back to the
Classic voice. Set `"political": true` if it's political, so people who turn
politics off never see it.

### Other files

- [`panels.json`](content/panels.json): the Pundit Panel (left, right, and the weather's reply)
- [`pundits.json`](content/pundits.json): the cast of made-up pundits. Fictional names only, never real people
- [`election.json`](content/election.json): Election Night winner lines and approval ratings
- [`loading.json`](content/loading.json): the loading screen

## House rules

The tests check the format automatically. Reviewers check these:

1. **Roast the weather, or the person checking it.** Never groups of people.
   No slurs, nothing about race, religion, gender, sexuality or disability.
2. **Politics roasts everyone equally.** If you add a jab at one side, add one
   at the other. No real politicians or real people by name.
3. **Funny beats filthy.** Swearing is seasoning, not the meal.
4. **Keep it short.** If it needs explaining, it's not a punchline.
5. **Original only.** Don't paste jokes from other apps or comedians.

## Checking your change locally (optional)

```sh
flutter test test/content_test.dart
```

The CI runs the same check on every pull request and tells you exactly which
line has a problem.

## Code contributions

Also welcome. Run `flutter analyze` and `flutter test --exclude-tags screenshots`
before opening a PR. To refresh the screenshots in `docs/`, run
`flutter test --tags screenshots --update-goldens`.
