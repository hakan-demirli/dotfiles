**Left Hand Wiring:**
Pulldown resistor at GP10 on left.
Pullup   resistor at GP10 on right.

Top View:
```
              |   |       
UART-1 GP0     ___        40
     2                    39
     3       _            38
     4      |o|           37
     5       '            36-3.3V
     6                    35
     7               GP28 34-C4
     8        ____        33-GND
     9       |    |  GP27 32-D1
     10      |    |  GP26 31-D2
     11      |____|       30
     12              GP22 29-C3
     13                   28-GND
     14 GP10         GP21 27-D3
     15              GP20 26-C2
     16              GP19 25-C1
     17              GP18 24-C5
     18                   23-GND
     19              GP17 22-C6
     20              GP16 21-C7
```

Matrix:
COL2ROW, current flows from columns to rows.
```
   C1 C2 C3 C4 C5 C6       
D1--o--o--o--o--o--o----\  
D2--o--o--o--o--o--o---\ \ 
D3--o--o--o--o--o--o--o o o C7
```

USB Wiring:
```
TP1 = GND
TP2 = DM(-)
TP3 = DP(+)
VBUS= V+
```
