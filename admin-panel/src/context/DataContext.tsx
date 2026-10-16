import React, { createContext, useCallback, useContext, useEffect, useRef, useState } from 'react';
import {
  DashboardData, OnlineData, PeriodSel, UserRow, fetchDashboard, fetchOnline, fetchUsers,
} from '../lib/api';

interface DataContextValue {
  period: PeriodSel;
  setPeriod: (p: PeriodSel) => void;
  data: DashboardData | null;
  loading: boolean;
  error: string | null;
  users: UserRow[] | null;
  usersLoading: boolean;
  usersError: string | null;
  loadUsers: () => void;
  online: OnlineData | null;
  refresh: () => void;
  lastUpdated: number | null;
}

const DataContext = createContext<DataContextValue | undefined>(undefined);

function readPeriod(): PeriodSel {
  try {
    const raw = localStorage.getItem('treepnet_period');
    if (raw) {
      const p = JSON.parse(raw) as PeriodSel;
      if (p && (p.kind === 'preset' || (p.kind === 'range' && p.from && p.to))) return p;
    }
  } catch {
    /* ignore */
  }
  return { kind: 'preset', preset: '7d' };
}

export const DataProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [period, setPeriodState] = useState<PeriodSel>(readPeriod);
  const [data, setData] = useState<DashboardData | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [users, setUsers] = useState<UserRow[] | null>(null);
  const [usersLoading, setUsersLoading] = useState(false);
  const [usersError, setUsersError] = useState<string | null>(null);
  const [online, setOnline] = useState<OnlineData | null>(null);
  const [lastUpdated, setLastUpdated] = useState<number | null>(null);
  const reqId = useRef(0);
  const usersWanted = useRef(false);

  const loadDashboard = useCallback(async (p: PeriodSel) => {
    const id = ++reqId.current;
    setLoading(true);
    setError(null);
    try {
      const d = await fetchDashboard(p);
      if (id !== reqId.current) return; // a newer period was picked meanwhile
      setData(d);
      setLastUpdated(Date.now());
    } catch (e) {
      if (id === reqId.current) setError(e instanceof Error ? e.message : String(e));
    } finally {
      if (id === reqId.current) setLoading(false);
    }
  }, []);

  const loadUsers = useCallback(async () => {
    usersWanted.current = true;
    setUsersLoading(true);
    setUsersError(null);
    try {
      setUsers((await fetchUsers()).users);
    } catch (e) {
      setUsersError(e instanceof Error ? e.message : String(e));
    } finally {
      setUsersLoading(false);
    }
  }, []);

  const loadOnline = useCallback(async () => {
    try {
      setOnline(await fetchOnline());
    } catch {
      /* keep the last value; the pill just stops updating */
    }
  }, []);

  useEffect(() => {
    loadDashboard(period);
  }, [period, loadDashboard]);

  useEffect(() => {
    loadOnline();
    const t = setInterval(loadOnline, 30000);
    return () => clearInterval(t);
  }, [loadOnline]);

  const setPeriod = (p: PeriodSel) => {
    setPeriodState(p);
    try {
      localStorage.setItem('treepnet_period', JSON.stringify(p));
    } catch {
      /* ignore */
    }
  };

  const refresh = () => {
    loadDashboard(period);
    loadOnline();
    if (usersWanted.current) loadUsers();
  };

  return (
    <DataContext.Provider
      value={{
        period, setPeriod, data, loading, error, users, usersLoading, usersError, loadUsers, online, refresh, lastUpdated,
      }}
    >
      {children}
    </DataContext.Provider>
  );
};

export function useData(): DataContextValue {
  const ctx = useContext(DataContext);
  if (!ctx) throw new Error('useData must be used within DataProvider');
  return ctx;
}

/** For views rendered only after the first successful load. */
export function useDashboard(): DashboardData {
  const { data } = useData();
  if (!data) throw new Error('dashboard not loaded');
  return data;
}
