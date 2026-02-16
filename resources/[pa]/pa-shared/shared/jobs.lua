--[[
Config Schema: jobs.lua
- Register under PaSharedConfigRegistry.jobs
- version (string): config revision.
- defaults (table): shared defaults for all jobs.
  - paycheckIntervalMinutes (number)
  - dutyRequired (boolean)
- cityHall (table): starter job center location data.
- jobs (table<string, table>): keyed by job id.
  - label (string)
  - legalRole (boolean)
  - starter (boolean)
  - grades (array<table>): ordered grade definitions.
    - level (number), name (string), salary (number)
  - payRules (table): optional paycheck overrides.
    - dutyRequired (boolean)
    - starterPay (number)
  - dutyLocations (array<table>): duty marker positions.
  - uniforms (table|nil): optional role uniforms per gender/grade.
  - jobActions (array<table>): target-zone actions.
  - requirements (table): licenses/reputation gates.
How to extend:
1) Add a job entry with at least one grade.
2) Keep salaries integer values for cleaner economy balancing.
3) Add clear requirements so City Hall UI can show why a job is locked.
]]

PaSharedConfigRegistry = PaSharedConfigRegistry or {}

PaSharedConfigRegistry.jobs = {
    version = '1.2.0',
    defaults = {
        paycheckIntervalMinutes = 30,
        dutyRequired = true,
    },
    cityHall = {
        coords = { x = -552.26, y = -191.03, z = 38.22 },
        radius = 2.0,
    },
    jobs = {
        unemployed = {
            label = 'Unemployed',
            legalRole = true,
            starter = false,
            grades = {
                { level = 0, name = 'Citizen', salary = 0 },
            },
            payRules = { dutyRequired = false, starterPay = 0 },
            dutyLocations = {},
            uniforms = nil,
            jobActions = {},
            requirements = { licenses = {}, minReputation = 0 },
        },

        delivery = {
            label = 'Port Aurora Courier',
            legalRole = true,
            starter = true,
            grades = {
                { level = 0, name = 'Courier', salary = 340 },
                { level = 1, name = 'Senior Courier', salary = 430 },
            },
            payRules = { dutyRequired = true, starterPay = 340 },
            dutyLocations = {
                { x = 78.92, y = 111.27, z = 81.17 },
            },
            uniforms = nil,
            jobActions = {
                { id = 'delivery_dispatch', label = 'Collect Delivery Route', coords = { x = 73.01, y = 111.91, z = 79.17 }, radius = 2.0 },
            },
            requirements = { licenses = {}, minReputation = 0 },
        },
        taxi = {
            label = 'Aurora Metro Taxi',
            legalRole = true,
            starter = true,
            grades = {
                { level = 0, name = 'Driver', salary = 320 },
                { level = 1, name = 'Senior Driver', salary = 420 },
            },
            payRules = { dutyRequired = true, starterPay = 320 },
            dutyLocations = {
                { x = 895.04, y = -179.44, z = 73.7 },
            },
            uniforms = nil,
            jobActions = {
                { id = 'taxi_shift_board', label = 'Start Taxi Shift', coords = { x = 901.3, y = -170.0, z = 74.08 }, radius = 2.0 },
            },
            requirements = { licenses = { 'driver' }, minReputation = 0 },
        },
        garbage = {
            label = 'City Sanitation',
            legalRole = true,
            starter = true,
            grades = {
                { level = 0, name = 'Collector', salary = 310 },
                { level = 1, name = 'Route Lead', salary = 390 },
            },
            payRules = { dutyRequired = true, starterPay = 310 },
            dutyLocations = {
                { x = -322.51, y = -1545.38, z = 31.02 },
            },
            uniforms = nil,
            jobActions = {
                { id = 'garbage_dispatch', label = 'Collect Route Sheet', coords = { x = -321.97, y = -1546.48, z = 31.02 }, radius = 2.0 },
            },
            requirements = { licenses = {}, minReputation = 0 },
        },

        tow = {
            label = 'Aurora Tow Services',
            legalRole = true,
            starter = true,
            grades = {
                { level = 0, name = 'Tow Operator', salary = 350 },
                { level = 1, name = 'Senior Operator', salary = 450 },
            },
            payRules = { dutyRequired = true, starterPay = 350 },
            dutyLocations = {
                { x = 409.16, y = -1623.89, z = 29.29 },
            },
            uniforms = nil,
            jobActions = {
                { id = 'tow_impound', label = 'Open Tow Dispatch', coords = { x = 408.0, y = -1625.35, z = 29.29 }, radius = 2.0 },
            },
            requirements = { licenses = { 'driver' }, minReputation = 5 },
        },
        ems = {
            label = 'Port Aurora EMS',
            legalRole = true,
            starter = true,
            grades = {
                { level = 0, name = 'EMT', salary = 500 },
                { level = 1, name = 'Paramedic', salary = 700 },
                { level = 2, name = 'Supervisor', salary = 900 },
            },
            payRules = { dutyRequired = true, starterPay = 500 },
            dutyLocations = {
                { x = 307.58, y = -595.04, z = 43.28 },
            },
            uniforms = {
                male = { shirt = 15, pants = 24 },
                female = { shirt = 14, pants = 23 },
            },
            jobActions = {
                { id = 'ems_locker', label = 'Open EMS Locker', coords = { x = 300.75, y = -597.09, z = 43.28 }, radius = 2.0 },
            },
            requirements = { licenses = { 'ems_cert' }, minReputation = 10 },
        },

        construction = {
            label = 'City Public Works',
            legalRole = true,
            starter = true,
            grades = {
                { level = 0, name = 'Laborer', salary = 360 },
                { level = 1, name = 'Site Lead', salary = 470 },
            },
            payRules = { dutyRequired = true, starterPay = 360 },
            dutyLocations = {
                { x = -510.51, y = -1001.73, z = 23.55 },
            },
            uniforms = nil,
            jobActions = {
                { id = 'construction_brief', label = 'View City Project Board', coords = { x = -515.4, y = -997.7, z = 23.55 }, radius = 2.0 },
            },
            requirements = { licenses = {}, minReputation = 8 },
        },
        police = {
            label = 'Port Aurora Police Department',
            legalRole = true,
            starter = false,
            grades = {
                { level = 0, name = 'Cadet', salary = 450 },
                { level = 1, name = 'Officer', salary = 650 },
                { level = 2, name = 'Sergeant', salary = 850 },
            },
            payRules = { dutyRequired = true, starterPay = 450 },
            dutyLocations = {
                { x = 441.3, y = -981.86, z = 30.69 },
            },
            uniforms = {
                male = { shirt = 55, pants = 35 },
                female = { shirt = 48, pants = 34 },
            },
            jobActions = {
                { id = 'pd_armory', label = 'Open Armory', coords = { x = 482.88, y = -995.33, z = 30.69 }, radius = 2.0 },
            },
            requirements = { licenses = { 'driver' }, minReputation = 30 },
        },
    },
}
