// Luanti
// SPDX-License-Identifier: LGPL-2.1-or-later
// Copyright (C) 2013 celeron55, Perttu Ahola <celeron55@gmail.com>

#pragma once

#include "guiButton.h"
#include "IGUIButton.h"

class Client;
class GUIItemImage;

class GUIButtonItemImage : public GUIButton
{
public:
	//! constructor
	GUIButtonItemImage(irr::gui::IGUIEnvironment *environment, irr::gui::IGUIElement *parent,
			s32 id, irr::core::rect<s32> rectangle, ISimpleTextureSource *tsrc,
			const std::string &item, Client *client, bool noclip = false);

	//! Do not drop returned handle
	static GUIButtonItemImage *addButton(irr::gui::IGUIEnvironment *environment,
			const irr::core::rect<s32> &rectangle, ISimpleTextureSource *tsrc,
			irr::gui::IGUIElement *parent, s32 id, const wchar_t *text,
			const std::string &item, Client *client);

private:
	Client *m_client;
	GUIItemImage *m_image;
};
