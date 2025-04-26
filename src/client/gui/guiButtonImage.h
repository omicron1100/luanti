// Luanti
// SPDX-License-Identifier: LGPL-2.1-or-later
// Copyright (C) 2013 celeron55, Perttu Ahola <celeron55@gmail.com>

#pragma once

#include "guiButton.h"
#include "IGUIButton.h"
#include "guiAnimatedImage.h"
#include "irr_ptr.h"

class GUIButtonImage : public GUIButton
{
public:
	//! constructor
	GUIButtonImage(irr::gui::IGUIEnvironment *environment, irr::gui::IGUIElement *parent,
			s32 id, irr::core::rect<s32> rectangle, ISimpleTextureSource *tsrc,
			bool noclip = false);

	void setForegroundImage(irr_ptr<irr::video::ITexture> image = nullptr,
			const irr::core::rect<s32> &middle = irr::core::rect<s32>());

	//! Set element properties from a StyleSpec
	virtual void setFromStyle(const StyleSpec &style) override;

	//! Do not drop returned handle
	static GUIButtonImage *addButton(irr::gui::IGUIEnvironment *environment,
			const irr::core::rect<s32> &rectangle, ISimpleTextureSource *tsrc,
			irr::gui::IGUIElement *parent, s32 id, const wchar_t *text,
			const wchar_t *tooltiptext = L"");

private:
	irr_ptr<irr::video::ITexture> m_foreground_image;
	irr_ptr<GUIAnimatedImage> m_image;
};
