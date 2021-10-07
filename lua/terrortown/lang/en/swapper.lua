local L = LANG.GetLanguageTableReference("en")

-- GENERAL ROLE LANGUAGE STRINGS
L[roles.SWAPPER.name] = "Swapper"
L["info_popup_" .. roles.SWAPPER.name] = [[You are the swapper, now go get killed!]]
L["body_found_" .. roles.SWAPPER.abbr] = "They were a Swapper!?"
L["search_role_" .. roles.SWAPPER.abbr] = "This person was a Swapper!?"
L["target_" .. roles.SWAPPER.name] = "Swapper"
L["ttt2_desc_" .. roles.SWAPPER.name] = [[The swapper is a Jester role that will steal its killers identity when killed and resurrect their killer as the new swapper!]]

-- OTHER ROLE LANGUAGE STRINGS
L["ttt2_role_swapper_inform_opposite"] = "You'll respawn as a random opposite role of your killer this round!"
L["ttt2_role_swapper_inform_same"] = "You'll respawn as the same role as your killer this round!"
L["ttt2_role_swapper_inform_wait"] = "You'll only respawn once your killer dies this round!"
L["ttt2_role_swapper_inform_instant"] = "You'll respawn after {delay} seconds once killed this round!"