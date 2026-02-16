--[[
Config Schema: story_chapters.lua
- Register under PaSharedConfigRegistry.story_chapters
- version (string): config revision.
- defaults (table): generic chapter defaults.
  - enabled (boolean)
  - recommendedLevel (number)
- chapters (array<table>): ordered chapters.
  - id (string)
  - title (string)
  - enabled (boolean)
  - recommendedLevel (number)
  - summary (string)
How to extend:
1) Add chapters in chronological order.
2) Keep id unique and permanent for save-state compatibility.
]]

PaSharedConfigRegistry = PaSharedConfigRegistry or {}

PaSharedConfigRegistry.story_chapters = {
    version = '1.0.0',
    defaults = {
        enabled = true,
        recommendedLevel = 1,
    },
    chapters = {
        {
            id = 'arrival',
            title = 'Chapter 1: Arrival in Aurora',
            enabled = true,
            recommendedLevel = 1,
            summary = 'Introduce players to neighborhoods, civic systems, and first legal/criminal opportunities.',
        },
        {
            id = 'fault_lines',
            title = 'Chapter 2: Fault Lines',
            enabled = true,
            recommendedLevel = 3,
            summary = 'Escalating tension between institutions, factions, and media narratives.',
        },
    },
}
