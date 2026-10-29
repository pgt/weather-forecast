# Weather Forecast

A Ruby on Rails app that receives an address and shows its weather forecast: current temperature, feels like, today's high/low and the next 7 days. Forecasts are cached for 30 minutes by zip code, and the page shows whether the result came from the cache.

- Ruby 4.0.9, Rails 8.1
- Geocoding: [Nominatim](https://nominatim.org/) (OpenStreetMap)
- Weather: [Open-Meteo](https://open-meteo.com/)
- Cache: `Rails.cache` backed by Redis

Neither API requires a key, so the project runs right after cloning.

## Running

### With Docker (recommended)

```bash
docker compose up --build
```

Open http://localhost:3000. This starts the production image (Puma with 2 workers) and Redis.

### Without Docker

```bash
bundle install
bin/rails server
```

Without `REDIS_URL` the development environment uses an in-memory cache, so Redis is optional. To use Redis locally:

```bash
REDIS_URL=redis://localhost:6379/0 bin/rails server
```

### Tests and linters

```bash
bin/rspec                  # tests
COVERAGE=true bin/rspec    # tests + coverage report in coverage/index.html
bin/rubocop
bin/brakeman
bin/bundler-audit
bin/ci                     # all of the above, the same steps as GitHub Actions
```

The tests never hit the network: the integrations replay VCR cassettes (`spec/fixtures/vcr_cassettes`) and everything else uses WebMock stubs. To record the cassettes again, delete them and run the specs (or run with `VCR_OFF=true` to talk to the real APIs).

### Configuration

All optional:

| Variable | Default | Description |
|---|---|---|
| `REDIS_URL` | `redis://localhost:6379/0` (production) | Cache store |
| `NOMINATIM_USER_AGENT` | `weather-forecast/1.0` | Nominatim [asks](https://operations.osmfoundation.org/policies/nominatim/) for an identifying User-Agent, ideally with a contact |
| `NOMINATIM_URL` | `https://nominatim.openstreetmap.org` | e.g. a self-hosted instance |
| `OPEN_METEO_URL` | `https://api.open-meteo.com` | e.g. a commercial endpoint |
| `RAILS_MAX_THREADS` / `WEB_CONCURRENCY` | `3` / `1` | Puma threads per worker / workers |

## Usage

**HTML:** fill in the address and choose the unit (Fahrenheit by default).

**JSON:** the same endpoint with `.json`:

```bash
curl 'http://localhost:3000/forecast.json?address=350+5th+Ave,+New+York,+NY&unit=celsius'
```

```json
{
  "address": "350 5th Ave, New York, NY",
  "cached": false,
  "location": {
    "zip_code": "10118",
    "country_code": "us",
    "display_name": "Empire State Building, 350, 5th Avenue, ..., New York, 10118, United States",
    "latitude": 40.7484,
    "longitude": -73.9857
  },
  "forecast": {
    "unit": "celsius",
    "current_temperature": 15.2,
    "feels_like": 13.9,
    "condition": "Overcast",
    "timezone": "America/New_York",
    "fetched_at": "2026-10-27T16:21:20Z",
    "days": [{ "date": "2026-10-27", "high": 17.1, "low": 9.8, "condition": "Slight rain" }]
  }
}
```

Errors return `{ "error": "..." }` with:

- `422` when the input is invalid, the address does not exist, or it has no zip code (e.g. only a city). The user can fix these.
- `503` when an upstream API times out, is down, rate limits us, or returns something we can't parse. Trying again later may work.

## Approach

```
ForecastsController            validates input (ForecastSearch), renders HTML/JSON, maps errors to 422/503
  └─ ForecastService           orchestrates geocoding + forecast, owns the caching rules
       ├─ Nominatim::Finders::Location   address → Location(zip_code, country_code, lat, lon)
       └─ OpenMeteo::Finders::Forecast   lat/lon → Forecast(current, feels like, 7 days)
            └─ HttpClient                Faraday: timeouts, retry, responses with success?/error, logging
```

```
app/
  controllers/forecasts_controller.rb
  services/forecast_service.rb, forecast_service/result.rb
  integrations/
    http_client.rb, http_client/response.rb, http_client/logging.rb
    nominatim/client.rb, nominatim/finders/location.rb
    open_meteo/client.rb, open_meteo/finders/forecast.rb, open_meteo/weather_codes.rb
  models/
    location.rb, forecast.rb, forecast/day.rb   models without database (ActiveModel)
    forecast/formatter.rb                       unit conversion + JSON
    forecast_search.rb                          form object (ActiveModel)
```

The main ideas:

- **Each integration is a `Client` + `Finder`.** The client knows how to connect (URL, headers, timeouts) and the finder knows the endpoint and turns the response into a value object. Nothing outside `app/integrations` knows about Nominatim or Open-Meteo, so replacing a provider means writing a new finder that returns the same `Location`/`Forecast`.
- **Models instead of hashes.** `Location` and `Forecast` use `ActiveModel::Model` + `ActiveModel::Attributes`: typed attributes and validations, without a database. The finders build them from the API response and check `valid?`, so a response missing fields becomes an `:invalid_response` error instead of breaking later.
- **No exceptions for flow control.** `HttpClient#get` returns a `Response` with `success?` and `error`, the finders return `nil` and expose `error`, and `ForecastService` returns a `Result` with `success?`, `error` and `cached?`. The only `rescue` is in `HttpClient`, because Faraday signals network failures only by raising.
- **The domain stores Celsius only.** The conversion happens in `Forecast::Formatter` when presenting, so Fahrenheit and Celsius share the same cache entry and we never lose precision converting back and forth.
- **No database.** There is nothing to persist, so the app is generated with `--skip-active-record`. Transient data goes to `Rails.cache`.

### Why these libraries

- **Faraday** (+ `faraday-retry`): middleware for timeouts, retry with backoff, `Retry-After` support and JSON parsing, keeping the integration code small. `Net::HTTP` alone would need all of that written by hand.
- **Redis** via `:redis_cache_store`: shared by all Puma workers and containers, has TTL per key and LRU eviction. Memcached would work too; Redis was chosen because it is the most common choice in Rails apps and easy to run in docker compose.
- **RSpec, VCR and WebMock**: VCR records real responses, so the happy paths are tested against what the APIs really return; WebMock covers what is hard to reproduce with real APIs (timeouts, DNS failures, 5xx, 429, invalid JSON).
- **Nominatim and Open-Meteo**: free, no API key, worldwide coverage (not only the US). The trade-off is their usage limits, see [Scaling](#concurrency-and-scaling).

## Architectural decisions and trade-offs

**Cache key: country + zip code, not only zip code.** The requirement is caching by zip code, but zip codes are not unique worldwide (10115 is in Berlin and in New York). The key is `forecast/v1/<country>/<zip>`.

**A zip code is an area, not a point.** The forecast is fetched for the coordinates of the *first* address requested in that zip code, and all the other addresses in it reuse that for 30 minutes. For weather this is a good approximation (zip codes are small compared to forecast grids), and it's what makes caching by zip code useful. Large rural zip codes could have differences; caching by rounded coordinates would be more precise but would break the requirement.

**Addresses without zip code are rejected.** A city ("Mountain View, CA") geocodes to a point without postcode. Instead of guessing a zip code we return 422 asking for a more specific address, because the whole caching strategy is based on it.

**Zip code normalization.** OSM sometimes returns ZIP+4 (`94043-1351`) or more than one postcode (`94043;94044`). We keep only the first 5-digit zip, so all of them share the same cache entry.

**Geocoding is cached too (1 day).** Not required, but Nominatim allows 1 request/second and an address does not change its zip code. The key is a SHA256 of the normalized address, so the user's address (possibly their home) is never stored as plain text in Redis.

**Failures and "not found" are not cached.** The next request tries again. Caching negative results for a short time would protect the APIs from repeated bad input, but it's not needed at this scale.

**Server-rendered HTML + JSON in the same controller.** The requirement prioritizes function over form, so the HTML is intentionally plain (no JavaScript). The JSON response is cheap to add with `respond_to` and makes the app usable as an API.

**GET with query string.** `/forecast?address=...` is idempotent, can be bookmarked and shared, and doesn't need CSRF protection.

## Caching and eviction policy

- **TTL:** forecasts expire after 30 minutes (`expires_in: 30.minutes`), geocoding after 1 day.
- **Cache indicator:** the block given to `Rails.cache.fetch` only runs on a miss, so a flag set inside it tells whether the result came from the cache. The page also shows when the forecast was fetched, in the location's timezone.
- **Stampede protection:** `race_condition_ttl: 10.seconds`. When an entry expires, the first request extends the old value for 10 seconds while it fetches a new one, so concurrent requests for the same zip code don't all hit the API at once. Because of that, Rails stores the key in Redis with 5 extra minutes of TTL (`TTL weather-forecast:forecast/v1/us/10118` shows ~2100s), but the entry still expires logically after 30 minutes: Rails checks the entry's own expiration on read.
- **Memory eviction:** Redis runs with `maxmemory 64mb` and `maxmemory-policy allkeys-lru`. If the memory is full, it evicts the least recently used keys instead of refusing writes, which is the right behavior for a cache. Popular zip codes stay, rare ones go.
- **No persistence:** RDB/AOF are disabled in docker compose. Losing the cache on restart only costs a few extra API calls.
- **Versioned keys:** keys have a `v1` (`ForecastService::CACHE_VERSION`). If `Forecast` or `Location` change, bumping it makes a deploy ignore the old entries instead of failing to load them.
- **Redis is optional at runtime:** the store has short timeouts (connect 1s, read/write 0.5s) and an `error_handler`. If Redis is down, `fetch` behaves as a miss, logs a warning and the request still works, just slower.

## Resilience

- **Timeouts:** `open_timeout` 2s, `read_timeout` 3s for Open-Meteo and 5s for Nominatim (new searches without results can take more than 3s, I saw it in practice).
- **Retry:** only once, only for GETs, only for timeouts, connection failures, 429 and 5xx, with exponential backoff and jitter. If the upstream asks to wait more than 1 second (`Retry-After`), we don't retry: sleeping would hold a Puma thread. Worst case is about `2 × (open + read) + 1s` per upstream.
- **Errors as values:** `HttpClient` turns every failure into a `Response` error: `:unavailable` (timeouts, DNS, connection refused, 5xx), `:rate_limited` (429) or `:invalid_response` (other 4xx, invalid JSON). The finders add `:address_not_found` and `:invalid_response` (when the model is not valid), and the service adds `:zip_code_not_found`. The controller maps the user errors to 422 and the upstream errors to a friendly 503.
- **Logging:** each upstream call is logged with host, path, result and duration (`HttpClient::Logging`). Params are not logged, since they contain the user's address.

## Concurrency and scaling

**The app is stateless.** All shared state is in Redis, so it scales horizontally: add Puma workers (`WEB_CONCURRENCY`) or containers behind a load balancer, and all of them share the same cache. Docker compose already runs 2 workers to show that.

**Thread safety.** The objects are created per request (`ForecastService.new` in the controller) and every cache read deserializes a new copy of the model, so there is no shared mutable state between threads. The Redis pool has one connection per Puma thread.

**I/O-bound workload.** Most of the time is spent waiting for the APIs. Puma threads handle that well because Ruby releases the GVL during I/O. A cache hit takes ~10ms, a miss ~0.5–2s. Under heavy load the hit ratio is what matters: the number of zip codes is limited (~42k in the US), so after warming up most requests should be hits.

**The bottleneck is the free APIs, not the app:**

- Public Nominatim allows **1 request/second** for the whole app. Geocoding cache helps for repeated addresses, but new addresses are always a miss. In production I would self-host Nominatim or use a commercial geocoder (Google, Mapbox), and add a distributed rate limiter (e.g. a Redis token bucket) in front of it.
- Open-Meteo's free tier allows 10,000 requests/day and is non-commercial. Production would use their commercial plan. With caching by zip code, 10k/day covers ~200 zip codes refreshed every 30 minutes all day long.

**Slow upstreams vs. thread exhaustion.** With the timeouts above, a slow upstream can hold a thread for several seconds. With many concurrent misses this could exhaust the Puma threads. The next step would be a circuit breaker (e.g. `stoplight` or `semian`): after some failures, fail fast for a while instead of waiting for timeouts.

**Cold-key stampede.** `race_condition_ttl` protects only entries that are expiring. If many requests for a never-seen zip code arrive at the same time, all of them miss. A short Redis lock per key would solve it, but it adds complexity that the expected traffic doesn't justify.

## Testing

83 examples, 100% line and branch coverage (`COVERAGE=true bin/rspec`, minimum enforced at 95% / 85%).

- `spec/integrations`: `HttpClient` against every failure (open/read timeout, DNS failure, 5xx with and without recovery, 429 with `Retry-After`, 4xx, invalid JSON) and the retry rules; the finders against VCR cassettes (address with zip, city without zip, nonexistent address) and stubs for unexpected formats.
- `spec/services`: caching rules with `travel` (cached at 29 min, refreshed at 31 min), cache shared between addresses of the same zip code, not shared between countries, failures not cached, geocoding cache key hashed.
- `spec/requests`: the whole stack with WebMock, HTML and JSON, cache indicator, 422 and 503 cases.
- `spec/models`: unit conversion and input validation.

## Challenges

- **Retry on status codes stopped working** after I customized the retry exceptions: `faraday-retry` signals `retry_statuses` with `Faraday::RetriableResponse`, which must stay in the list.
- **Nominatim is slower than expected** for searches without results (more than 3s sometimes), which first showed up as a 503 for an address that simply doesn't exist. Its read timeout is now 5s.

## Next steps

With more time I would:

- Add a circuit breaker around the upstream calls.
- Add a distributed rate limiter for Nominatim (1 req/s across all processes), or move to a self-hosted/commercial geocoder.
- Cache "not found" results for a few minutes.
- Add a lock for cold keys (see stampede above).
- Add metrics (cache hit ratio, upstream latency and errors) with StatsD/Prometheus, and error tracking (Sentry).
- Add address autocomplete in the form to reduce "no zip code" errors.
- Use HTTP caching headers (`Cache-Control`, `ETag`) on the JSON endpoint.
