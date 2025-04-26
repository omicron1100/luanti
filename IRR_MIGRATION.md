## Irrlicht Dependencies

### 1. Core Irrlicht Types (irrlichttypes.h)
- `src/clientdynamicinfo.h`
- `src/database/database.h`
- `src/gamedef.h`
- `src/gameparams.h`
- `src/hud.h`
- `src/map.h`
- `src/objdef.h`
- `src/object_properties.h`
- `src/network/address.h`
- `src/particles.h`
- `src/profiler.h`
- `src/network/networkpacket.h`
- `src/network/socket.h`
- `src/settings.h`
- `src/sound.h`
- `src/staticobject.h`
- `src/tool.h`
- `src/voxel.h`
- `src/util/container.h`
- `src/util/directiontables.h`
- `src/util/ieee_float.h`
- `src/util/numeric.h`
- `src/util/png.h`
- `src/util/pointabilities.h`
- `src/util/pointedthing.h`
- `src/util/serialize.h`
- `src/util/string.h`
- `src/util/timetaker.h`
- `src/util/thread.h`
- `src/texture_override.h`
- `src/tileanimation.h`
- `src/serialization.h`
- `src/server/serveractiveobject.h`
- `src/script/common/c_packer.h`
- `src/script/common/c_converter.h`
- `src/script/common/c_content.h`
- `src/network/networkprotocol.h`
- `src/script/cpp_api/s_base.h`
- `src/reflowscan.h`
- `src/network/connection.h`
- `src/porting.h`
- `src/player.h`
- `src/nodedef.h`
- `src/gui/touchcontrols.h`
- `src/gui/StyleSpec.h`
- `src/nameidmapping.h`
- `src/modifiedstate.h`
- `src/modchannels.h`
- `src/gui/modalMenu.h`
- `src/script/lua_api/l_itemstackmeta.h`
- `src/mapsector.h`
- `src/mapnode.h`
- `src/script/lua_api/l_nodemeta.h`
- `src/script/lua_api/l_object.h`
- `src/script/lua_api/l_playermeta.h`
- `src/script/lua_api/l_metadata.h`
- `src/main.cpp`
- `src/log_internal.h`
- `src/light.h`
- `src/gui/guiFormSpecMenu.h`
- `src/gui/guiEngine.h`
- `src/gui/guiEditBox.h`
- `src/itemdef.h`
- `src/irr_v3d.h`

### 2. Irrlicht Changes (irrlicht_changes/)
- `src/nodemetadata.cpp`
- `src/particles.h`
- `src/pathfinder.cpp`
- `src/serverenvironment.cpp`
- `src/servermap.cpp`
- `src/unittest/test_collision.cpp`
- `src/voxel.h`
- `src/network/serverpackethandler.cpp`
- `src/server/luaentity_sao.cpp`
- `src/rollback_interface.cpp`
- `src/script/cpp_api/s_item.cpp`
- `src/object_properties.cpp`
- `src/mapblock.cpp`
- `src/map.cpp`
- `src/main.cpp`
- `src/gui/guiTable.cpp`
- `src/gui/guiHyperText.cpp`
- `src/gui/guiFormSpecMenu.cpp`
- `src/gui/guiEngine.cpp`
- `src/gui/guiChatConsole.cpp`
- `src/gui/guiButton.cpp`

### 3. Direct Irrlicht Headers
- `src/gui/touchcontrols.cpp` (includes `<IrrlichtDevice.h>`)
- `src/main.cpp` (includes `irrlicht.h`)
- `src/unittest/test_irr_gltf_mesh_loader.cpp` (includes `irrlicht.h`)

### 4. Irrlicht Vector Types
- `src/server/clientiface.h` (includes `irr_v3d.h`)

### Categories of Dependencies
1. Type definitions and utilities (irrlichttypes.h)
2. Modified Irrlicht components (irrlicht_changes/)
3. Direct Irrlicht engine dependencies
4. Vector and math utilities