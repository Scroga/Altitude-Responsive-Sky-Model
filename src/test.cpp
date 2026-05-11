#include "test.hpp"

using namespace godot;

void Test::_bind_methods() {
	ClassDB::bind_method(D_METHOD("print_hello"), &Test::print_hello);

	ClassDB::bind_method(D_METHOD("get_text"), &Test::get_text);
	ClassDB::bind_method(D_METHOD("set_text", "new_text"), &Test::set_text);

	ADD_PROPERTY(PropertyInfo(Variant::STRING, "text"), "set_text", "get_text");
}

String Test::get_text() const {
	return text;
}
void Test::set_text(const String &new_text) {
	text = new_text;
}

void Test::print_hello() const {
	print_line("Hello");
}
