module shingeki

import net
import log
import sync

const (
	logger = log.Log{log.INFO, 'terminal'}
)

struct Server {
	instance 	net.Socket
mut:
	clients 	map[string]net.Socket
	pairs 		map[string]string
	mtx 		sync.Mutex
}

fn (server mut Server) register(fd string, client net.Socket) {
	server.clients[fd] = client
	logger.info(server.list())
}

fn (server mut Server) unregister(fd string) {
	if (fd in server.clients) {
		logger.warn('Unregistering $fd~')
		mut client := server.clients[fd]
		client.close() or {}
		server.clients.delete(fd)
		logger.info(server.list())
	}
}

fn (server mut Server) is_chatting(fd string) bool {
	return (fd in server.pairs)  // lazily
}

fn (server mut Server) join_chat(fd string) {
	logger.info('$fd is joining chat!')
	mut client := server.clients[fd]
	if (fd in server.pairs) {
		client.write('You have already joined chat~')
	} else {
		// find someone
		mut found := false
		for partner_fd in server.pairs.keys() {
			another_fd := server.pairs[partner_fd]
			if another_fd.len == 0 {
				// someone is waiting~
				found = true
				mut partner_client := server.clients[partner_fd]
				partner_client.write('Start chatting with $fd, enjoy~')
				client.write('Start chatting with $partner_fd, enjoy~')
				logger.info('$fd is now chatting with $partner_fd!')
				server.pairs[partner_fd] = fd
				server.pairs[fd] = partner_fd
				break
			}
		}
		if !found {
			logger.info('$fd is waiting for a partner to chat!')
			client.write('Waiting for a partner...')
			server.pairs[fd] = ''
		}
	}
}

fn (server mut Server) leave_chat(fd string) {
	logger.info('$fd is leaving chat...')
	mut client := server.clients[fd]
	if (fd in server.pairs) {
		// if joined chat
		partner_fd := server.pairs[fd]
		if partner_fd.len > 0 && (partner_fd in server.pairs) {
			// if chatting with a partner
			mut partner_client := server.clients[partner_fd]
			partner_client.write('Your partner $fd leaves you alone...')
			server.pairs.delete(partner_fd)
			logger.info('$fd has left chat with $partner_fd!')
		} else {
			logger.warn('Cannot find partner with $fd!')
		}
		server.pairs.delete(fd)
		client.write('You have left your chat~')
	}
}

fn (server mut Server) handle_chat(fd string, msg string) {
	mut client := server.clients[fd]
	partner_fd := server.pairs[fd]
	if partner_fd.len > 0 {
		message := '$fd: $msg'
		mut partner_client := server.clients[partner_fd]
		partner_client.write(message)
	} else {
		client.write('You are now chatting with air...sad~')
	}
}

fn (server mut Server) help() string {
	return '\r\nShinGeKiNoV Commands:\r\n' +
		'chat\ttry find someone to chat with\r\n' +
		'list\tlist all clients\r\n' +
		'exit\tdisconnect ShinGeKiNoV or quit chat\r\n'
}

fn (server mut Server) list() string {
	mut list := '\r\nCurrent clients are:\r\n'
	mut cnt := 0
	for fd in server.clients.keys() {
		cnt++
		mut partner_fd := ''
		mut status := 'idle'
		if (fd in server.pairs) {
			partner_fd = server.pairs[fd]
			if partner_fd.len == 0 {
				status = 'waiting'
			} else {
				status = 'chatting with $partner_fd'
			}
		}
		list += 'No.$cnt\tfd: $fd\tstatus: $status\r\n'
	}
	list += 'Overall $cnt clients!\r\n'
	return list
}

pub fn (server mut Server) start() {
	for {
		socket := server.instance.accept() or { panic(err) }
		go handle(socket, server)
	}
}

fn handle(s net.Socket, server mut Server) {
	fdint := s.sockfd
	fd := fdint.str()
	logger.info('$fd connected!!!')
	s.write('$fd: Welcome to ShinGeKiNoV Chat Platform~')
	server.mtx.lock()
	server.register(fd, s)
	server.mtx.unlock()
	for {
		msg := s.read_line().replace('\r\n', '').replace('\n', '')
		if msg.len > 0 {
			logger.info('Received message size ${msg.len} from $fd: $msg')
		}
		server.mtx.lock()
		if server.is_chatting(fd) {
			match msg {
				'' {
					logger.warn('$fd itself disconnected...')
					server.leave_chat(fd)
					server.unregister(fd)
					break
				}
				'exit' {
					logger.warn('$fd is going to leave chat...')
					server.leave_chat(fd)
				}
				else {
					server.handle_chat(fd, msg)
				}
			}
		} else {
			match msg {
				'' {
					logger.warn('$fd itself disconnected...')
					server.leave_chat(fd)
					server.unregister(fd)
					break
				}
				'exit' {
					logger.warn('$fd is requesting to disconnect...')
					s.write('Disconnecting...')
					server.leave_chat(fd)
					server.unregister(fd)
					break
				}
				'help' {
					s.write(server.help())
				}
				'list' {
					s.write(server.list())
				}
				'chat' {
					server.join_chat(fd)
				}
				else {
					s.write('Invalid command: $msg! Type "help" for options~')
				}
			}
		}
		server.mtx.unlock()
	}
}

pub fn server() Server {
	instance := net.listen(5000) or { panic(err) }
	port := instance.get_port()
	logger.info('Server is listening at 127.0.0.1:$port!')
	mut mtx := sync.new_mutex()
	mut clients := map[string]net.Socket
	mut pairs := map[string]string
	return Server{instance, clients, pairs, mtx}
}
