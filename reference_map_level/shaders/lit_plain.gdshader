shader_type canvas_item;
// Только свет по карте нормалей — для спрайтов без своего материала
// (обрывы, каньон, лестницы). Ставит scripts/normal_maps.gd.

#include "res://reference_map_level/shaders/normal_light.gdshaderinc"
