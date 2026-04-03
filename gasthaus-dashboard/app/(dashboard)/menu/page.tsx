'use client'

import { useState, useMemo, useRef, useEffect } from 'react'
import { useQuery, useQueryClient, useMutation } from '@tanstack/react-query'
import { Search, Plus, X, Upload, Trash2 } from 'lucide-react'
import api from '@/lib/api'
import type { MenuCategory, MenuItem } from '@/types'

// ── types ──────────────────────────────────────────────────────────────────

interface EditForm {
  name: string
  description: string
  price: string
  categoryId: string
  isAvailable: boolean
  imageFile: File | null
  previewUrl: string | null
}

const EMPTY_FORM: EditForm = {
  name: '',
  description: '',
  price: '',
  categoryId: '',
  isAvailable: true,
  imageFile: null,
  previewUrl: null,
}

// ── page ───────────────────────────────────────────────────────────────────

export default function MenuPage() {
  const queryClient                     = useQueryClient()
  const [search, setSearch]             = useState('')
  const [activeCatId, setActiveCatId]   = useState<string | null>(null) // null = All
  const [editItem, setEditItem]         = useState<MenuItem | 'new' | null>(null)
  const [form, setForm]                 = useState<EditForm>(EMPTY_FORM)
  const [addingCategory, setAddingCategory] = useState(false)
  const [newCategoryName, setNewCategoryName] = useState('')
  const fileRef                         = useRef<HTMLInputElement>(null)

  const { data: categories = [] } = useQuery<MenuCategory[]>({
    queryKey: ['menu-categories'],
    queryFn:  () => api.get<MenuCategory[]>('/menu/categories?all=true').then((r) => r.data),
  })

  // Flatten all items with their category
  const allItems: MenuItem[] = useMemo(
    () => categories.flatMap((c) => (c.items ?? []).map((i) => ({ ...i, categoryId: c.id, category: c }))),
    [categories],
  )

  // Filtered items
  const visibleItems = useMemo(() => {
    return allItems.filter((i) => {
      if (activeCatId && i.categoryId !== activeCatId) return false
      if (search && !i.name.toLowerCase().includes(search.toLowerCase())) return false
      return true
    })
  }, [allItems, activeCatId, search])

  // ── mutations ──────────────────────────────────────────────────────────

  const { mutate: toggleItem } = useMutation({
    mutationFn: (id: string) => api.patch(`/menu/items/${id}/toggle`),
    onSuccess:  () => queryClient.invalidateQueries({ queryKey: ['menu-categories'] }),
  })

  const { mutate: deleteItem, isPending: deleting } = useMutation({
    mutationFn: (id: string) => api.delete(`/menu/items/${id}`),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['menu-categories'] })
      setEditItem(null)
    },
  })

  const { mutate: saveItem, isPending: saving } = useMutation({
    mutationFn: async (data: EditForm) => {
      const fd = new FormData()
      fd.append('name',        data.name)
      fd.append('description', data.description)
      fd.append('price',       data.price)
      fd.append('categoryId',  data.categoryId)
      fd.append('isAvailable', String(data.isAvailable))
      if (data.imageFile) fd.append('image', data.imageFile)

      if (editItem === 'new') {
        return api.post('/menu/items', fd, { headers: { 'Content-Type': 'multipart/form-data' } })
      } else {
        const id = (editItem as MenuItem).id
        return api.patch(`/menu/items/${id}`, fd, { headers: { 'Content-Type': 'multipart/form-data' } })
      }
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['menu-categories'] })
      setEditItem(null)
    },
  })

  const { mutate: addCategory } = useMutation({
    mutationFn: (name: string) => api.post('/menu/categories', { name }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['menu-categories'] })
      setAddingCategory(false)
      setNewCategoryName('')
    },
  })

  const { mutate: deleteCategory } = useMutation({
    mutationFn: (id: string) => api.delete(`/menu/categories/${id}`),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['menu-categories'] })
      if (activeCatId) setActiveCatId(null)
    },
  })

  // ── edit panel helpers ─────────────────────────────────────────────────

  function openEdit(item: MenuItem) {
    setForm({
      name:        item.name,
      description: item.description ?? '',
      price:       String(item.price),
      categoryId:  item.categoryId,
      isAvailable: item.isAvailable,
      imageFile:   null,
      previewUrl:  item.imageUrl ?? null,
    })
    setEditItem(item)
  }

  function openNew() {
    setForm({ ...EMPTY_FORM, categoryId: activeCatId ?? categories[0]?.id ?? '' })
    setEditItem('new')
  }

  function handleFileChange(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0]
    if (!file) return
    setForm((f) => ({ ...f, imageFile: file, previewUrl: URL.createObjectURL(file) }))
  }

  // Clean up blob URLs
  useEffect(() => {
    return () => {
      if (form.previewUrl?.startsWith('blob:')) URL.revokeObjectURL(form.previewUrl)
    }
  }, [form.previewUrl])

  return (
    <div className="flex h-[calc(100vh-52px)] overflow-hidden">

      {/* ── Category sidebar ───────────────────────────────────────── */}
      <aside className="w-[200px] shrink-0 bg-white border-r border-[#E5E7EB] flex flex-col py-6 overflow-y-auto">
        <p className="px-6 mb-3 text-[10px] font-bold text-[#6B7280] uppercase tracking-widest">
          Categories
        </p>

        <div className="space-y-0.5 px-3">
          {/* All items */}
          <button
            onClick={() => setActiveCatId(null)}
            className={`w-full flex justify-between items-center px-3 py-2 rounded-lg text-sm transition-colors ${
              activeCatId === null
                ? 'bg-amber-50 text-[#D97706] font-semibold'
                : 'text-[#374151] hover:bg-[#F9F9F7]'
            }`}
          >
            <span>All Items</span>
            <span className={`text-xs ${activeCatId === null ? 'text-[#D97706]' : 'text-[#9CA3AF]'}`}>
              {allItems.length}
            </span>
          </button>

          {/* Per-category */}
          {categories.map((cat) => (
            <div key={cat.id} className="group relative">
              <button
                onClick={() => setActiveCatId(cat.id)}
                className={`w-full flex justify-between items-center px-3 py-2 rounded-lg text-sm transition-colors ${
                  activeCatId === cat.id
                    ? 'bg-amber-50 text-[#D97706] font-semibold'
                    : 'text-[#374151] hover:bg-[#F9F9F7]'
                }`}
              >
                <span className="truncate">{cat.name}</span>
                <span className="text-xs text-[#9CA3AF] group-hover:invisible">{cat.items?.length ?? 0}</span>
              </button>
              {/* Delete category (hover) */}
              <button
                onClick={() => deleteCategory(cat.id)}
                className="absolute right-1 top-1/2 -translate-y-1/2 hidden group-hover:flex w-5 h-5 items-center justify-center text-red-400 hover:text-red-600 transition-colors"
                title="Delete category"
              >
                <X size={12} />
              </button>
            </div>
          ))}
        </div>

        {/* Add category */}
        <div className="mt-4 px-3">
          {addingCategory ? (
            <div className="space-y-2">
              <input
                autoFocus
                value={newCategoryName}
                onChange={(e) => setNewCategoryName(e.target.value)}
                onKeyDown={(e) => {
                  if (e.key === 'Enter' && newCategoryName.trim()) addCategory(newCategoryName.trim())
                  if (e.key === 'Escape') { setAddingCategory(false); setNewCategoryName('') }
                }}
                placeholder="Category name"
                className="w-full border border-[#E5E7EB] rounded-lg px-3 py-1.5 text-xs focus:outline-none focus:border-[#D97706]"
              />
              <div className="flex gap-2">
                <button
                  onClick={() => newCategoryName.trim() && addCategory(newCategoryName.trim())}
                  className="flex-1 bg-[#D97706] text-white text-xs font-bold py-1.5 rounded-lg hover:bg-[#B45309]"
                >
                  Add
                </button>
                <button
                  onClick={() => { setAddingCategory(false); setNewCategoryName('') }}
                  className="flex-1 border border-[#E5E7EB] text-[#6B7280] text-xs font-bold py-1.5 rounded-lg hover:bg-[#F9F9F7]"
                >
                  Cancel
                </button>
              </div>
            </div>
          ) : (
            <button
              onClick={() => setAddingCategory(true)}
              className="w-full flex items-center justify-center gap-1.5 px-3 py-2 border-2 border-dashed border-[#E5E7EB] rounded-lg text-[#6B7280] hover:border-[#D97706] hover:text-[#D97706] transition-all text-xs font-medium"
            >
              <Plus size={12} /> Add Category
            </button>
          )}
        </div>
      </aside>

      {/* ── Item grid ─────────────────────────────────────────────── */}
      <section className="flex-1 bg-[#F9F9F7] p-8 overflow-y-auto">
        {/* Content header */}
        <div className="flex justify-between items-center mb-6">
          <div>
            <h3 className="text-base font-semibold text-zinc-900">
              {activeCatId ? (categories.find((c) => c.id === activeCatId)?.name ?? 'Items') : 'All Items'}
            </h3>
            <p className="text-sm text-[#6B7280]">
              {visibleItems.length} item{visibleItems.length !== 1 ? 's' : ''}
              {search && ` matching "${search}"`}
            </p>
          </div>
          <div className="flex items-center gap-3">
            {/* Search */}
            <div className="relative">
              <Search size={13} className="absolute left-3 top-1/2 -translate-y-1/2 text-[#9CA3AF]" />
              <input
                value={search}
                onChange={(e) => setSearch(e.target.value)}
                placeholder="Search menu..."
                className="bg-white border border-[#E5E7EB] pl-8 pr-3 py-1.5 rounded-lg text-sm focus:outline-none focus:border-[#D97706] w-52 transition-all"
              />
            </div>
            {/* Add item */}
            <button
              onClick={openNew}
              className="flex items-center gap-2 bg-[#D97706] text-white text-sm font-semibold px-4 py-2 rounded-lg hover:bg-[#B45309] transition-colors"
            >
              <Plus size={15} /> Add Item
            </button>
          </div>
        </div>

        {/* Grid */}
        {visibleItems.length === 0 ? (
          <div className="flex flex-col items-center justify-center py-20 text-[#9CA3AF]">
            <p className="text-sm">No items found</p>
          </div>
        ) : (
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            {visibleItems.map((item) => (
              <ItemCard
                key={item.id}
                item={item}
                selected={editItem !== null && editItem !== 'new' && (editItem as MenuItem).id === item.id}
                onEdit={() => openEdit(item)}
                onToggle={() => toggleItem(item.id)}
              />
            ))}
          </div>
        )}
      </section>

      {/* ── Edit panel ────────────────────────────────────────────── */}
      {editItem !== null && (
        <aside className="w-[360px] shrink-0 bg-white border-l border-[#E5E7EB] flex flex-col p-6 overflow-y-auto">
          {/* Panel header */}
          <div className="flex items-center justify-between mb-6">
            <h3 className="font-semibold text-zinc-900 text-sm">
              {editItem === 'new' ? 'New Item' : `Edit: ${(editItem as MenuItem).name}`}
            </h3>
            <button
              onClick={() => setEditItem(null)}
              className="text-[#9CA3AF] hover:text-zinc-900 transition-colors"
            >
              <X size={18} />
            </button>
          </div>

          <div className="space-y-5 flex-1">
            {/* Image upload */}
            <div>
              <label className="block text-[10px] font-bold text-[#6B7280] uppercase tracking-widest mb-2">
                Item Image
              </label>
              <div
                onClick={() => fileRef.current?.click()}
                className="aspect-video border-2 border-dashed border-[#E5E7EB] rounded-lg flex flex-col items-center justify-center cursor-pointer hover:border-[#D97706] transition-all overflow-hidden relative bg-[#F9F9F7]"
              >
                {form.previewUrl ? (
                  <img
                    src={form.previewUrl}
                    alt="Preview"
                    className="absolute inset-0 w-full h-full object-cover"
                  />
                ) : (
                  <>
                    <Upload size={20} className="text-[#9CA3AF]" />
                    <p className="text-[11px] text-[#9CA3AF] mt-1.5 font-medium">Upload image</p>
                  </>
                )}
                {form.previewUrl && (
                  <div className="absolute inset-0 bg-black/20 flex items-center justify-center opacity-0 hover:opacity-100 transition-opacity">
                    <Upload size={20} className="text-white" />
                  </div>
                )}
              </div>
              <input
                ref={fileRef}
                type="file"
                accept="image/*"
                className="hidden"
                onChange={handleFileChange}
              />
            </div>

            {/* Name */}
            <FormField label="Item Name">
              <input
                value={form.name}
                onChange={(e) => setForm((f) => ({ ...f, name: e.target.value }))}
                className="w-full border-0 border-b border-[#E5E7EB] focus:border-[#D97706] focus:outline-none text-sm font-medium py-2 bg-transparent text-zinc-900"
                placeholder="e.g. Chicken Karahi"
              />
            </FormField>

            {/* Description */}
            <FormField label="Description">
              <textarea
                value={form.description}
                onChange={(e) => setForm((f) => ({ ...f, description: e.target.value }))}
                rows={3}
                className="w-full border-0 border-b border-[#E5E7EB] focus:border-[#D97706] focus:outline-none text-sm py-2 resize-none bg-transparent text-zinc-900"
                placeholder="Brief description..."
              />
            </FormField>

            {/* Price + Category */}
            <div className="grid grid-cols-2 gap-4">
              <FormField label="Price (Rs.)">
                <input
                  type="number"
                  value={form.price}
                  onChange={(e) => setForm((f) => ({ ...f, price: e.target.value }))}
                  className="w-full border-0 border-b border-[#E5E7EB] focus:border-[#D97706] focus:outline-none text-sm font-medium py-2 bg-transparent text-zinc-900"
                  placeholder="0"
                />
              </FormField>
              <FormField label="Category">
                <select
                  value={form.categoryId}
                  onChange={(e) => setForm((f) => ({ ...f, categoryId: e.target.value }))}
                  className="w-full border-0 border-b border-[#E5E7EB] focus:border-[#D97706] focus:outline-none text-sm font-medium py-2 bg-transparent text-zinc-900"
                >
                  <option value="">Select…</option>
                  {categories.map((c) => (
                    <option key={c.id} value={c.id}>{c.name}</option>
                  ))}
                </select>
              </FormField>
            </div>

            {/* Availability toggle */}
            <div className="flex items-center justify-between py-4 border-y border-[#F4F4F2]">
              <div>
                <p className="text-sm font-semibold text-zinc-900">Availability</p>
                <p className="text-xs text-[#6B7280]">Visible on customer menu</p>
              </div>
              <button
                type="button"
                onClick={() => setForm((f) => ({ ...f, isAvailable: !f.isAvailable }))}
                className={`w-10 h-5 rounded-full relative transition-colors ${
                  form.isAvailable ? 'bg-[#D97706]' : 'bg-[#E5E7EB]'
                }`}
              >
                <span
                  className={`absolute top-0.5 w-4 h-4 bg-white rounded-full shadow transition-all ${
                    form.isAvailable ? 'left-[22px]' : 'left-0.5'
                  }`}
                />
              </button>
            </div>

            {/* Save / Discard */}
            <div className="space-y-3 pt-2">
              <button
                onClick={() => saveItem(form)}
                disabled={saving || !form.name || !form.price || !form.categoryId}
                className="w-full bg-[#D97706] text-white py-3 rounded-lg text-sm font-bold hover:bg-[#B45309] transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
              >
                {saving ? 'Saving…' : 'Save Changes'}
              </button>
              <button
                onClick={() => setEditItem(null)}
                className="w-full bg-white border border-[#E5E7EB] text-[#6B7280] py-3 rounded-lg text-sm font-bold hover:bg-[#F9F9F7] transition-colors"
              >
                Discard
              </button>
            </div>

            {/* Delete (only when editing existing) */}
            {editItem !== 'new' && (
              <div className="pt-2">
                <button
                  onClick={() => {
                    if (confirm('Remove this item from the menu?')) {
                      deleteItem((editItem as MenuItem).id)
                    }
                  }}
                  disabled={deleting}
                  className="w-full flex items-center justify-center gap-2 text-red-500 text-[11px] font-bold uppercase tracking-widest hover:underline disabled:opacity-50"
                >
                  <Trash2 size={13} />
                  {deleting ? 'Removing…' : 'Remove from Menu'}
                </button>
              </div>
            )}
          </div>
        </aside>
      )}
    </div>
  )
}

// ── ItemCard ───────────────────────────────────────────────────────────────

function ItemCard({
  item,
  selected,
  onEdit,
  onToggle,
}: {
  item: MenuItem
  selected: boolean
  onEdit: () => void
  onToggle: () => void
}) {
  return (
    <div
      className={[
        'bg-white border rounded-lg overflow-hidden cursor-pointer transition-all',
        selected
          ? 'ring-2 ring-[#D97706] border-[#D97706]'
          : item.isAvailable
            ? 'border-[#E5E7EB] hover:border-[#D97706]/40'
            : 'border-[#E5E7EB] opacity-60',
      ].join(' ')}
      onClick={onEdit}
    >
      {/* Image */}
      <div className={`h-[140px] bg-[#EEEEEC] overflow-hidden ${!item.isAvailable ? 'grayscale' : ''}`}>
        {item.imageUrl ? (
          <img
            src={item.imageUrl}
            alt={item.name}
            className="w-full h-full object-cover group-hover:scale-105 transition-transform duration-500"
          />
        ) : (
          <div className="w-full h-full flex items-center justify-center text-[#9CA3AF] text-xs uppercase tracking-widest">
            No image
          </div>
        )}
      </div>

      {/* Body */}
      <div className="p-4">
        <div className="flex justify-between items-start mb-1">
          <h4 className="font-semibold text-zinc-900 text-sm">{item.name}</h4>
          <span className="font-bold text-[#D97706] text-sm shrink-0 ml-2">
            Rs. {item.price.toLocaleString()}
          </span>
        </div>
        <p className="text-[11px] text-[#6B7280] mb-4 uppercase tracking-tight">
          {item.category?.name ?? '—'}
        </p>

        {/* Availability row */}
        <div
          className="flex items-center justify-between pt-3 border-t border-[#F4F4F2]"
          onClick={(e) => e.stopPropagation()}
        >
          <span className={`text-[10px] font-bold uppercase ${item.isAvailable ? 'text-[#78350F]' : 'text-[#9CA3AF]'}`}>
            {item.isAvailable ? 'Available' : 'Unavailable'}
          </span>
          <button
            onClick={onToggle}
            className={`w-8 h-4 rounded-full relative transition-colors ${
              item.isAvailable ? 'bg-[#D97706]' : 'bg-[#E5E7EB]'
            }`}
          >
            <span
              className={`absolute top-0.5 w-3 h-3 bg-white rounded-full shadow transition-all ${
                item.isAvailable ? 'left-[18px]' : 'left-0.5'
              }`}
            />
          </button>
        </div>
      </div>
    </div>
  )
}

// ── FormField ──────────────────────────────────────────────────────────────

function FormField({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <div>
      <label className="block text-[10px] font-bold text-[#6B7280] uppercase tracking-widest mb-1">
        {label}
      </label>
      {children}
    </div>
  )
}
