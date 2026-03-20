import axios from 'axios'
import { getToken, clearAuth } from './auth'

const api = axios.create({
  baseURL: process.env.NEXT_PUBLIC_API_URL ?? 'http://localhost:3001/api',
})

api.interceptors.request.use((config) => {
  const token = getToken()
  if (token) {
    config.headers.Authorization = `Bearer ${token}`
  }
  return config
})

api.interceptors.response.use(
  (response) => response,
  (error) => {
    // Only redirect to /login when a token existed but was rejected (expired/invalid session).
    // Do NOT redirect on a raw 401 from the login endpoint itself — that's just wrong credentials,
    // and the page should handle it locally without a full reload clearing component state.
    if (error.response?.status === 401 && getToken()) {
      clearAuth()
      if (typeof window !== 'undefined') {
        window.location.href = '/login'
      }
    }
    return Promise.reject(error)
  },
)

export default api
