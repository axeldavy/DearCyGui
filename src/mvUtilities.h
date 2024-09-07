#pragma once

//-----------------------------------------------------------------------------
// mvUtilities
//
//     - This file contains typically platform specific functions. May need
//       to rename to a more appropriate name.
//     
//-----------------------------------------------------------------------------

#include <vector>
#include <string>
#include "mvTypes.h"

#ifndef PyObject_HEAD
struct _object;
typedef _object PyObject;
#endif

struct PymvBuffer;

void* mvAllocateTexture(u32 width, u32 height, u32 num_chans, u32 dynamic, u32 type, u32 filtering_mode);
void mvFreeTexture(void* texture);

void mvUpdateDynamicTexture(void* texture, u32 width, u32 height, u32 num_chans, u32 type, void* data);
void mvUpdateStaticTexture(void* texture, u32 width, u32 height, u32 num_chans, u32 type, void* data);