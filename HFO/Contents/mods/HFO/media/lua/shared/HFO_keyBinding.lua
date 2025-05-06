--============================================================--
--                     HFO_keyBinding.lua                     --
--============================================================--
-- Purpose:
--   Registers custom key bindings for HFO.
--
-- Overview:
--   This script adds keyboard shortcuts for advanced weapon interactions,
--   including fire mode toggling, ammo cycling, melee mode, inspection,
--   magazine swaps, folding/unfolding, and integrated functions.

-- Notes:
--   - Keys are registered via keyBinding during game start
--   - Users can rebind these keys in the in-game key settings menu
--============================================================--
 
local bind = {};
bind.value = "[HFO]";
table.insert(keyBinding, bind);

bind = {};
bind.value = "AmmoChange";
bind.key = Keyboard.KEY_SEMICOLON;
table.insert(keyBinding, bind);

bind = {};
bind.value = "AmmoChangeReverse";
bind.key = Keyboard.KEY_APOSTROPHE;
table.insert(keyBinding, bind);

bind = {};
bind.value = "MeleeMode";
bind.key = Keyboard.KEY_HOME;
table.insert(keyBinding, bind);

bind = {};
bind.value = "FireMode";
bind.key = Keyboard.KEY_BACK;
table.insert(keyBinding, bind);

bind = {};
bind.value = "FireModeReverse";
bind.key = Keyboard.KEY_BACKSLASH;
table.insert(keyBinding, bind);

bind = {};
bind.value = "FoldUnfold";
bind.key = Keyboard.KEY_SLASH;
table.insert(keyBinding, bind);

bind = {};
bind.value = "Integrated";
bind.key = Keyboard.KEY_PERIOD;
table.insert(keyBinding, bind);

bind = {};
bind.value = "WeaponLight";
bind.key = Keyboard.KEY_RCONTROL;
table.insert(keyBinding, bind);

bind = {};
bind.value = "SwapMagazine";
bind.key = Keyboard.KEY_RBRACKET;
table.insert(keyBinding, bind);

bind = {};
bind.value = "SwapMagazineReverse";
bind.key = Keyboard.KEY_LBRACKET;
table.insert(keyBinding, bind);

bind = {};
bind.value = "InspectWeapon";
bind.key = Keyboard.KEY_RMENU;
table.insert(keyBinding, bind);

bind = {};
bind.value = "InnerVoiceToggle";
bind.key = Keyboard.KEY_COMMA;
table.insert(keyBinding, bind);