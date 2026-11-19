extends RefCounted
## Nomes usados nos dados das pistas e nos poderes, num lugar só (um erro de digitação vira
## erro de compilação em vez de bug silencioso).

# perigos da pista ("kind" em hazards)
const HZ_FLAME := "flame"
const HZ_WHEEL := "wheel"
const HZ_PRESS := "press"
const HZ_SEESAW := "seesaw"
const HZ_CROSSER := "crosser"
const HZ_ROOFCAT := "roofcat"   # atravessador com modelo de gato (Telhados)
const HZ_ROVER := "rover"

# zonas de superfície ("kind" em zones)
const ZN_FAROFA := "farofa"
const ZN_SAND := "sand"
const ZN_BELT := "belt"
const ZN_BELT_SIDE := "belt_side"
const ZN_GRILL := "grill"
const ZN_ICE := "ice"
const SLOW_ZONES := [ZN_FAROFA, ZN_SAND]   # a IA desvia dessas

# poderes ("id" em characters.power)
const PW_SLOWMO := "slowmo"
const PW_GUITAR := "guitar"
const PW_PLANT := "plant"
const PW_BASS := "bass"
const PW_GHOST := "ghost"
const PW_DRIFT := "drift"
const PW_RAM := "ram"
const PW_STEAL := "steal"

# perigo à frente (o que a IA recebe): chave que marca buraco
const AHEAD_PIT := "pit"
