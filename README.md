# MB10-Toolbox
[Toolbox v1](https://amazfitwatchfaces.com/mi-band/view/178) by [Neux](https://amazfitwatchfaces.com/ucp/561170) adapted to Mi Band 10

**Warning! I don't take any credit for this app!** I only decompiled it and changed a few variables to make it work on the Mi Band 10.

## What's different?
**The path variables to files and directories were changed**
- Old:
```
local appJsonPath = '/data/quickapp/apps.json'
local appJsonPathHide = '/data/quickapp/apps.js
local appPathApp = '/data/quickapp/app/'
```

- New:
```
local appJsonPath = '/data/apps.json'
local appJsonPathHide = '/data/apps.json_hide'
local appPathApp = '/data/app/'
```

That's literally it.

I wanted to adapt it to the bigger size of the Mi Band 10, but honestly, it's not needed to do that. The toolbox covers almost the entire screen.

## Want the decompiled app without any changes?
The original code is in the `orig_decomp` folder\
I hope Neux is fine with that :)

## Special thanks to
- [Neux](https://amazfitwatchfaces.com/ucp/561170) for providing the watchface
- [EasyFace](https://github.com/m0tral/EasyFace) for compiling
- [MiWatchEmulator](https://github.com/m0tral/MiWatchEmulator) for testing