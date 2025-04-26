// Luanti
// SPDX-License-Identifier: LGPL-2.1-or-later
// Copyright (C) 2013 celeron55, Perttu Ahola <celeron55@gmail.com>

#pragma once

#include <array>
#include <IGUIElement.h>
#include <IGUIEnvironment.h>

class GUIBox : public irr::gui::IGUIElement
{
public:
	GUIBox(irr::gui::IGUIEnvironment *env, irr::gui::IGUIElement *parent, s32 id,
		const irr::core::rect<s32> &rectangle,
		const std::array<irr::video::SColor, 4> &colors,
		const std::array<irr::video::SColor, 4> &bordercolors,
		const std::array<s32, 4> &borderwidths);

	virtual void draw() override;

private:
	std::array<irr::video::SColor, 4> m_colors;
	std::array<irr::video::SColor, 4> m_bordercolors;
	std::array<s32, 4> m_borderwidths;
};
