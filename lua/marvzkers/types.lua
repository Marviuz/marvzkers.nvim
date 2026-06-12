---@class Marker.Options
---@field save_path string
---@field save_file string
---@field colors Marker.Colors

---@class Marker.Colors
---@field inactive string
---@field active_row string
---@field active_row_col string

---@class Marker.Cursor
---@field row number
---@field col number
---@field note string?

---@class Marker.Data
---@field path string
---@field cursor Marker.Cursor

---@class Marker.Entry
---@field cursor Marker.Cursor
---@field note string?

---@class Marker.Api
---@field markers fun(): Marker.Entry[]

---@class Marker.JumpIndex
---@field index number

---@class Marker.JumpCoordinates
---@field row number
---@field col number

---@class Marker.ReplacementData
---@field path string
---@field cursors Marker.Cursor[]
