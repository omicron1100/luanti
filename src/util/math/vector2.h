// For Vector2 Files, to replace irrlicht's vector2d.h

#pragma once

template <typename T>
class Vec2 {
public:
    T x, y;

    Vec2(T x, T y) : x(x), y(y) {}

    Vec2 operator+(const Vec2& other) const {
        return Vec2(x + other.x, y + other.y);
    }
    
    
};

