import { io } from 'socket.io-client'

const WS_URL = process.env.NEXT_PUBLIC_WS_URL ?? 'http://localhost:3001'

const socket = io(WS_URL, {
  autoConnect: false,
})

export default socket
