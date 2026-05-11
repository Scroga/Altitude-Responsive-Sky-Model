#ifndef TEST_HPP
#define TEST_HPP

#include <godot_cpp/classes/node.hpp>
#include <godot_cpp/classes/wrapped.hpp>

using namespace godot;

class Test : public Node {
	GDCLASS(Test, Node)
protected:
	static void _bind_methods();

private:
	String text = "Some random text";

public:
	String get_text() const;
	void set_text(const String &new_text);

	void print_hello() const;
};

#endif
