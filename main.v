module main

import shingeki

fn debug_map() {
	mut harshmap := map[string]string
	key := 'haha'
	harshmap[key] = 'hehe'
	println(key)
	println(harshmap)
	println(key in harshmap)
	println(harshmap.size)
	println(harshmap.keys().len)
	println("\n-----------------------------\n")
	harshmap.delete(key)
	println(key)
	println(harshmap)
	println(key in harshmap)
	println(harshmap.size)
	println(harshmap.keys().len)
	println("\n-----------------------------\n")
	harshmap[key] = 'hehe'
	println(key)
	println(harshmap)
	println(key in harshmap)
	println(harshmap.size)
	println(harshmap.keys().len)
}

fn main() {
	// debug_map()
	mut server := shingeki.server()
	server.start()
}