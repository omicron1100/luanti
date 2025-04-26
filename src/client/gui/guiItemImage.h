// Luanti
// SPDX-License-Identifier: LGPL-2.1-or-later
// Copyright (C) 2013 celeron55, Perttu Ahola <celeron55@gmail.com>

#pragma once

#include <IGUIElement.h>
#include <IGUIEnvironment.h>

class Client;

class GUIItemImage : public irr::gui::IGUIElement
{
public:
	GUIItemImage(irr::gui::IGUIEnvironment *env, irr::gui::IGUIElement *parent, s32 id,
		const irr::core::rect<s32> &rectangle, const std::string &item_name,
		irr::gui::IGUIFont *font, Client *client);

	virtual void draw() override;

	virtual void setText(const wchar_t *text) override
	{
		m_label = text;
	}

private:
	std::string m_item_name;
	irr::gui::IGUIFont *m_font;
	Client *m_client;
	irr::core::stringw m_label;
};
