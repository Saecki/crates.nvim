local api = require("crates.api")
local time = require("crates.time")
local DateTime = time.DateTime
local types = require("crates.types")
local Features = types.Features
local SemVer = types.SemVer
local Range = types.Range

describe("crate", function()
	local json_str
	it("read file", function()
		json_str = io.input("test/rand.json"):read("a")
		assert.equals("string", type(json_str))
	end)

	it("parse json", function()
		local crate = api.parse_crate(json_str)
		assert.same({
			name = "rand",
			description = "Random number generators and other randomness functionality.\n",
			created = DateTime.new(os.time({
				year = 2015,
				month = 2,
				day = 3,
				hour = 6,
				min = 17,
				sec = 14,
			})),
			updated = DateTime.new(os.time({
				year = 2022,
				month = 2,
				day = 14,
				hour = 8,
				min = 37,
				sec = 47,
			})),
			downloads = 168678835,
			homepage = "https://rust-random.github.io/book",
			documentation = "https://docs.rs/rand",
			repository = "https://github.com/rust-random/rand",
			categories = { "Algorithms", "No standard library" },
			keywords = { "random", "rng" },
			versions = {
				{
					num = "0.8.5",
					features = Features.new({
						{ name = "default", members = { "std", "std_rng" } },
						{ name = "alloc", members = { "rand_core/alloc" } },
						{ name = "getrandom", members = { "rand_core/getrandom" } },
						{ name = "libc", members = {} },
						{ name = "min_const_gen", members = {} },
						{ name = "nightly", members = {} },
						{ name = "packed_simd", members = {} },
						{ name = "rand_chacha", members = {} },
						{ name = "serde", members = {} },
						{ name = "serde1", members = { "rand_core/serde1", "serde" } },
						{ name = "simd_support", members = { "packed_simd" } },
						{ name = "small_rng", members = {} },
						{
							name = "std",
							members = { "alloc", "getrandom", "libc", "rand_chacha/std", "rand_core/std" },
						},
						{ name = "std_rng", members = { "rand_chacha" } },
					}),
					yanked = false,
					parsed = SemVer.new({ major = 0, minor = 8, patch = 5 }),
					created = DateTime.new(os.time({
						year = 2022,
						month = 2,
						day = 14,
						hour = 8,
						min = 37,
						sec = 47,
					})),
				},
				{
					num = "0.3.5",
					features = Features.new({
						{ name = "default", members = {} },
					}),
					yanked = false,
					parsed = SemVer.new({ major = 0, minor = 3, patch = 5 }),
					created = DateTime.new(os.time({
						year = 2015,
						month = 4,
						day = 1,
						hour = 16,
						min = 31,
						sec = 9,
					})),
				},
				{
					num = "0.1.1",
					features = Features.new({
						{ name = "default", members = {} },
					}),
					yanked = true,
					parsed = SemVer.new({ major = 0, minor = 1, patch = 1 }),
					created = DateTime.new(os.time({
						year = 2015,
						month = 2,
						day = 3,
						hour = 6,
						min = 17,
						sec = 14,
					})),
				},
			},
		}, crate)
	end)
end)

describe("dependencies", function()
	local json_str
	it("read file", function()
		json_str = io.input("test/rand_dependencies.json"):read("a")
		assert.equals("string", type(json_str))
	end)

	it("parse json", function()
		local dependencies = api.parse_deps(json_str)
		assert.equals("table", type(dependencies))

		assert.same({
			{
				name = "average",
				opt = false,
				kind = "dev",
				vers = {
					reqs = {
						{
							cond = "cr",
							cond_col = Range.new(0, 1),
							vers = SemVer.new({ major = 0, minor = 9, patch = 2 }),
							vers_col = Range.new(1, 6),
						},
					},
					text = "^0.9.2",
				},
			},
			{
				name = "rand_core",
				opt = false,
				kind = "normal",
				vers = {
					reqs = {
						{
							cond = "cr",
							cond_col = Range.new(0, 1),
							vers = SemVer.new({ major = 0, minor = 3 }),
							vers_col = Range.new(1, 4),
						},
					},
					text = "^0.3",
				},
			},
			{
				name = "rustc_version",
				opt = false,
				kind = "build",
				vers = {
					reqs = {
						{
							cond = "cr",
							cond_col = Range.new(0, 1),
							vers = SemVer.new({ major = 0, minor = 2 }),
							vers_col = Range.new(1, 4),
						},
					},
					text = "^0.2",
				},
			},
			{
				name = "cloudabi",
				opt = true,
				kind = "normal",
				vers = {
					reqs = {
						{
							cond = "cr",
							cond_col = Range.new(0, 1),
							vers = SemVer.new({ major = 0, minor = 0, patch = 3 }),
							vers_col = Range.new(1, 6),
						},
					},
					text = "^0.0.3",
				},
			},
		}, dependencies)
	end)
end)
