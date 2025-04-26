// Luanti
// SPDX-License-Identifier: LGPL-2.1-or-later
// Copyright (C) 2015 Aaron Suen <warr1024@gmail.com>

#pragma once

#include "../types.h"
#include <path.h>
#include <rect.h>
#include <SColor.h>

namespace irr::video
{
	class IImage;
	class ITexture;
	class IVideoDriver;
}

/* Manually insert an image into the cache, useful to avoid texture-to-image
 * conversion whenever we can intercept it.
 */
void guiScalingCache(const irr::io::path &key, irr::video::IVideoDriver *driver, irr::video::IImage *value);

// Manually clear the cache, e.g. when switching to different worlds.
void guiScalingCacheClear();

/* Get a cached, high-quality pre-scaled texture for display purposes.  If the
 * texture is not already cached, attempt to create it.  Returns a pre-scaled texture,
 * or the original texture if unable to pre-scale it.
 */
irr::video::ITexture *guiScalingResizeCached(irr::video::IVideoDriver *driver, irr::video::ITexture *src,
		const irr::core::rect<s32> &srcrect, const irr::core::rect<s32> &destrect);

/* Convenience wrapper for guiScalingResizeCached that accepts parameters that
 * are available at GUI imagebutton creation time.
 */
irr::video::ITexture *guiScalingImageButton(irr::video::IVideoDriver *driver, irr::video::ITexture *src,
		s32 width, s32 height);

/* Replacement for driver->draw2DImage() that uses the high-quality pre-scaled
 * texture, if configured.
 */
void draw2DImageFilterScaled(irr::video::IVideoDriver *driver, irr::video::ITexture *txr,
		const irr::core::rect<s32> &destrect, const irr::core::rect<s32> &srcrect,
		const irr::core::rect<s32> *cliprect = nullptr,
		const irr::video::SColor *const colors = nullptr, bool usealpha = false);

/*
 * 9-slice / segment drawing
 */
void draw2DImage9Slice(irr::video::IVideoDriver *driver, irr::video::ITexture *texture,
		const irr::core::rect<s32> &destrect, const irr::core::rect<s32> &srcrect,
		const irr::core::rect<s32> &middlerect, const irr::core::rect<s32> *cliprect = nullptr,
		const irr::video::SColor *const colors = nullptr);
