# Cubescape
Small Puzzle Game for playing while lessons

## Allgemein
- Umkippen 
- Die Form des Spielsteins ist levelabhängig
- "Effekte" fuer verschiedene Seiten auswaehlen
- keine Grenze fuer die Nutzung von Effekten
- Perspektive
- Kamera:  yaw: (in blender steine)-50 Grad gedreht; roll 0; pitch:?
- Kamera folgt spieler
- Level Editor
- Voxel aussehen. Feste 3d Modelle, die immer gleich bleiben(statisch)
- Spielstein, besteht aus mehreren 3D Modellen(Seiten), die zusammengesetzt werden
- Kein Undo, sondern feste Checkpoints bei langen Levels
- Kronen-System: 3 Kronen (maximal) wenn man die von uns festgelegte Route findet; 2 Kronen: x bis y Zuege; 1 Krone: Level geschafft; 5 Kronen: man hat eine kuerzere Route als wir gefunden(Wird sehr selten passieren, vielleicht geheim halten, also keine 5 leere  Kronen)
- Levels in Ebenen gruppieren. Man kann zur naechste Ebene, nur wenn mann genug Kronen hat
- Effekten werden nicht vor dem Start des Levels gewaehlt, sondern (auf dem Boden) im Level gefunden und dann auf einer Seite "geklebt"

## Steine/Hindernisse 
- Spikes, man stirbt sofort, es sei denn, man hat Ruestung auf die Seite, mit der man auf dem Stein tritt
- Bewegliche Steine
- Loch
- Stein (einfache Wand)
-  Verwirrungs-Stein, der die Steuerung vorübergehend ändert, rechts wird links , vorne wird hinten. Leicht versteckt.Nachdem man dadrauf getreten ist, kann man den Stein sehen 



## Effekte
- Portal -> Man kann bestimmte Steine "ignorieren" 
- Ruestung -> Man stirbt nicht,wenn man auf z.B. einem Spike tritt . Es gibt zwei Arten: einmalige und permanente Ruestung
-  

## Vielleicht 
- Hotkey zum Kamera vom Spieler lösen, um das Level anzuschauen
- (?) Fog Of War (Stein-Effekt oder immer)
- GUI, um zu zeigen, was fuer Effekten auf welcher Seite man hat



Anmerkung: Spielstein != Stein: Spielstein -> der Spieler/-in; Stein  -> Hindernisse.  
## Offene Fragen
