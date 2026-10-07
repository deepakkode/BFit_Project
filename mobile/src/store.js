import { create } from 'zustand';

export const useAppStore = create((set) => ({
  user: null,
  isDark: false,
  setUser: (user) => set({ user }),
  toggleTheme: () => set((state) => ({ isDark: !state.isDark })),
  clearUser: () => set({ user: null }),
}));