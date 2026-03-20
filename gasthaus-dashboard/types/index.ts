export enum Role {
  CUSTOMER = 'CUSTOMER',
  WAITER = 'WAITER',
  KITCHEN = 'KITCHEN',
  MANAGER = 'MANAGER',
}

export enum OrderStatus {
  PENDING = 'PENDING',
  CONFIRMED = 'CONFIRMED',
  PREPARING = 'PREPARING',
  READY = 'READY',
  SERVED = 'SERVED',
  COMPLETED = 'COMPLETED',
  CANCELLED = 'CANCELLED',
}

export interface User {
  id: string
  name: string
  email: string
  role: Role
}

export interface MenuCategory {
  id: string
  name: string
  icon?: string
  items?: MenuItem[]
}

export interface MenuItem {
  id: string
  name: string
  description?: string
  price: number
  imageUrl?: string
  isAvailable: boolean
  categoryId: string
  category?: MenuCategory
}

export interface OrderItem {
  id: string
  quantity: number
  unitPrice: number
  notes?: string
  menuItem: MenuItem
}

export interface RestaurantTable {
  id: string
  tableNumber: number
  qrCode?: string
  isOccupied: boolean
  orders?: Order[]
}

export interface Order {
  id: string
  status: OrderStatus
  totalAmount: number
  createdAt: string
  customerId: string
  tableId?: string
  items: OrderItem[]
  customer?: User
  table?: RestaurantTable
}

export interface Review {
  id: string
  rating: number
  comment?: string
  createdAt: string
  customer?: User
  menuItem?: MenuItem
}
