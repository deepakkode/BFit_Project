import { useEffect, useState } from 'react';
import {
  ActivityIndicator, Alert, AppState, Dimensions, Image, Platform, Pressable, ScrollView, StyleSheet, Switch, Text, TextInput, View,
} from 'react-native';
import { isRunningInExpoGo } from 'expo';
import { StatusBar } from 'expo-status-bar';
import { DarkTheme, DefaultTheme, NavigationContainer } from '@react-navigation/native';
import { createBottomTabNavigator } from '@react-navigation/bottom-tabs';
import { SafeAreaProvider, useSafeAreaInsets } from 'react-native-safe-area-context';
import { QueryClient, QueryClientProvider, useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { BarChart, LineChart } from 'react-native-chart-kit';
import { API_BASE_URL, authApi, activityApi, analyticsApi, goalsApi, stepsApi } from './src/api';
import { useAppStore } from './src/store';
import { useActivitySensors } from './src/sensors';
import { clearAccessToken, getAccessToken, setAccessToken } from './src/tokenStorage';
import { getLastQuoteIndex, setLastQuoteIndex } from './src/quoteStorage';
import { estimateWalkingMetrics, getActivityReadingStatus, getDisplayActivityName, getGoalSummary, getNextQuoteIndex, getStepGoalRecommendation, MOTIVATIONAL_QUOTES, STARTER_DAILY_STEP_GOAL } from './src/wellnessMetrics.mjs';
import { cancelMovementReminder, configureMovementNotifications, getMovementReminderSettings, scheduleMovementReminder } from './src/reminders';
import { BrandMark, brandColors } from './src/BrandMark';

const queryClient = new QueryClient({ defaultOptions: { queries: { retry: 1, staleTime: 30000 } } });
const Tabs = createBottomTabNavigator();
const palette = {
  dark: { bg: '#0C1413', panel: '#111E1B', raised: '#1B2A27', text: '#EAF3EE', muted: '#A7B5AE', accent: '#7ED7B2', line: '#233933', orange: '#F3B881', red: '#E3887A', hero: '#122D27', heroMuted: '#94C8B1', heroAccent: '#E6F5EA' },
  light: { bg: '#F4F1EA', panel: '#FFFDF9', raised: '#EEE7DC', text: '#18322A', muted: '#5F756B', accent: '#3E8F6B', line: '#E5DDD1', orange: '#C57E58', red: '#D45E4F', hero: '#EAF7F0', heroMuted: '#456B5C', heroAccent: '#26493A' },
};

function useColors() {
  return palette[useAppStore((state) => state.isDark) ? 'dark' : 'light'];
}

function Page({ children, style }) {
  const colors = useColors();
  const insets = useSafeAreaInsets();
  return <ScrollView className="flex-1" style={{ backgroundColor: colors.bg }} contentContainerStyle={[styles.page, { paddingTop: 16 + insets.top, paddingBottom: 42 + insets.bottom }, style]}>{children}</ScrollView>;
}

function Label({ children, style }) {
  const colors = useColors();
  return <Text style={[styles.label, { color: colors.muted }, style]}>{children}</Text>;
}

function Title({ children, style }) {
  const colors = useColors();
  return <Text style={[styles.title, { color: colors.text }, style]}>{children}</Text>;
}

function Panel({ children, style }) {
  const colors = useColors();
  return <View style={[styles.panel, { backgroundColor: colors.panel, borderColor: colors.line }, style]}>{children}</View>;
}

function Pill({ children, color, background }) {
  return <View style={[styles.pill, { backgroundColor: background }]}><Text style={{ color, fontSize: 12, fontWeight: '700' }}>{children}</Text></View>;
}

function AuthScreen() {
  const colors = useColors();
  const insets = useSafeAreaInsets();
  const [isRegister, setIsRegister] = useState(false);
  const [name, setName] = useState('');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [age, setAge] = useState('');
  const [height, setHeight] = useState('');
  const [weight, setWeight] = useState('');
  const [gender, setGender] = useState('');
  const [error, setError] = useState('');
  const setUser = useAppStore((state) => state.setUser);
  const client = useQueryClient();
  const mutation = useMutation({
    mutationFn: async () => {
      setError('');
      if (isRegister) {
        await authApi.register({
          name: name.trim(),
          email: email.trim(),
          password,
          age: age ? Number(age) : null,
          height_cm: height ? Number(height) : null,
          weight_kg: weight ? Number(weight) : null,
          gender: gender || null,
        });
      }
      return authApi.login({ email: email.trim(), password });
    },
    onSuccess: async ({ access_token }) => {
      await setAccessToken(access_token);
      const profile = await authApi.profile();
      setUser(profile);
      client.invalidateQueries();
    },
    onError: (cause) => {
      const detail = cause.response?.data?.detail;
      setError(detail
        ? typeof detail === 'string' ? detail : JSON.stringify(detail)
        : `Couldn't reach ${API_BASE_URL}. Check that your phone has internet access. If the free Render server was idle, wait about a minute for it to wake up, then try again.`);
    },
  });

  return (
    <ScrollView className="flex-grow" contentContainerStyle={[styles.authPage, { backgroundColor: colors.bg, paddingTop: 20 + insets.top }]} keyboardShouldPersistTaps="handled">
      <View style={styles.brandLockup}>
        <BrandMark size={62} cutout={colors.bg} />
        <View style={styles.brandLockupText}>
          <Text style={[styles.brandWordmark, { color: colors.text }]}>BFit</Text>
          <Text style={[styles.brandTagline, { color: colors.muted }]}>BALANCED TODAY</Text>
          <Text style={[styles.brandTagline, { color: colors.muted }]}>BETTER TOMORROW</Text>
        </View>
      </View>
      <Label style={styles.authEyebrow}>A LITTLE MORE IN TUNE</Label>
      <Title style={styles.authTitle}>{isRegister ? 'Make space for\nfeeling good.' : 'Move well.\nFeel well.'}</Title>
      <Text style={[styles.authCopy, { color: colors.muted }]}>A thoughtful view of your everyday movement.</Text>
      {isRegister && <Field label="NAME" value={name} onChangeText={setName} placeholder="Your name" colors={colors} />}
      <Field label="EMAIL" value={email} onChangeText={setEmail} placeholder="you@example.com" keyboardType="email-address" autoCapitalize="none" colors={colors} />
      <Field label="PASSWORD" value={password} onChangeText={setPassword} placeholder="At least 8 characters" secureTextEntry colors={colors} />
      {isRegister && (
        <>
          <View style={styles.fieldRow}>
            <Field label="AGE" value={age} onChangeText={setAge} keyboardType="numeric" containerStyle={styles.fieldCompact} colors={colors} />
            <Field label="HEIGHT (cm)" value={height} onChangeText={setHeight} keyboardType="numeric" containerStyle={styles.fieldCompact} colors={colors} />
          </View>
          <Field label="WEIGHT (kg)" value={weight} onChangeText={setWeight} keyboardType="numeric" colors={colors} />
          <GenderPicker value={gender} onChange={setGender} colors={colors} />
        </>
      )}
      {error ? <Text style={{ color: colors.red, marginTop: 12 }}>{error}</Text> : null}
      <Pressable
        accessibilityRole="button"
        disabled={mutation.isPending || !email || password.length < 8 || (isRegister && !name.trim())}
        onPress={() => mutation.mutate()}
        style={[styles.primaryButton, { backgroundColor: colors.accent, opacity: mutation.isPending ? 0.65 : 1 }]}
      >
        {mutation.isPending ? <ActivityIndicator color={colors.bg} /> : <Text style={[styles.primaryButtonText, { color: colors.bg }]}>{isRegister ? 'Create account' : 'Sign in'}  →</Text>}
      </Pressable>
      <Pressable onPress={() => { setIsRegister((value) => !value); setError(''); }} style={styles.textButton}>
        <Text style={{ color: colors.muted }}>{isRegister ? 'Already have an account? ' : 'New to BFit? '}<Text style={{ color: colors.accent, fontWeight: '700' }}>{isRegister ? 'Sign in' : 'Create account'}</Text></Text>
      </Pressable>
    </ScrollView>
  );
}

function Field({ label, colors, containerStyle, ...props }) {
  return (
    <View style={[styles.field, containerStyle]}>
      <Label>{label}</Label>
      <TextInput placeholderTextColor={colors.muted} style={[styles.input, { backgroundColor: colors.panel, borderColor: colors.line, color: colors.text }]} {...props} />
    </View>
  );
}

function GenderPicker({ value, onChange, colors }) {
  return (
    <View style={styles.genderPicker}>
      {['Female', 'Male', 'Other', 'Prefer not to say'].map((option) => {
        const selected = value === option;
        return (
          <Pressable
            key={option}
            accessibilityRole="radio"
            accessibilityState={{ selected }}
            onPress={() => onChange(option)}
            style={[
              styles.genderOption,
              {
                borderColor: selected ? colors.accent : colors.line,
                backgroundColor: selected ? colors.hero : colors.panel,
              },
            ]}
          >
            <Text style={{ color: selected ? colors.accent : colors.text, fontWeight: '700' }}>
              {selected ? '✓  ' : ''}{option}
            </Text>
          </Pressable>
        );
      })}
    </View>
  );
}

function HomeScreen() {
  const colors = useColors();
  const user = useAppStore((state) => state.user);
  const [permissionRefreshToken, setPermissionRefreshToken] = useState(0);
  const [quote, setQuote] = useState(MOTIVATIONAL_QUOTES[0]);
  const current = useQuery({ queryKey: ['activity', 'current'], queryFn: activityApi.current, refetchInterval: 15000 });
  const today = useQuery({ queryKey: ['activity', 'today'], queryFn: activityApi.today });
  const steps = useQuery({ queryKey: ['steps', 'today'], queryFn: stepsApi.today, refetchInterval: 60000 });
  const stepHistory = useQuery({ queryKey: ['steps', 'history'], queryFn: stepsApi.history, staleTime: 300000 });
  const goals = useQuery({ queryKey: ['goals'], queryFn: goalsApi.get });
  const pedometerStatus = useActivitySensors(true, user, permissionRefreshToken);
  const stepPermissionRequired = pedometerStatus.includes('Allow physical activity access');
  const recommendation = getStepGoalRecommendation(stepHistory.data || [], new Date(), user || {});

  const errorMessage = current.error?.response?.data?.detail || 'Connect to the BFit API to start tracking.';
  const stepCount = steps.data?.steps || 0;
  const goal = Number(goals.data?.daily_step_goal || recommendation.dailyStepGoal || STARTER_DAILY_STEP_GOAL);
  const progress = Math.min(stepCount / goal, 1);
  const estimatedMetrics = estimateWalkingMetrics(stepCount, user);
  const activityStatus = getActivityReadingStatus(current.data);
  const detectionIsStale = activityStatus.isStale;
  const activityNote = current.isError && !current.data?.activity ? errorMessage : activityStatus.note;

  useEffect(() => {
    let active = true;
    let isLoading = false;
    let lastIndex = null;
    const showNextQuote = async () => {
      if (isLoading) return;
      isLoading = true;
      const previousIndex = lastIndex ?? await getLastQuoteIndex();
      const nextIndex = getNextQuoteIndex(MOTIVATIONAL_QUOTES, previousIndex);
      lastIndex = nextIndex;
      if (!active) return;
      setQuote(MOTIVATIONAL_QUOTES[nextIndex]);
      setLastQuoteIndex(nextIndex);
      isLoading = false;
    };
    showNextQuote();
    const subscription = AppState.addEventListener('change', (state) => {
      if (state === 'active') showNextQuote();
    });
    return () => {
      active = false;
      subscription.remove();
    };
  }, []);
  return (
    <Page>
      <View style={styles.headerRow}>
        <View><Label>{new Date().toLocaleDateString(undefined, { weekday: 'long', month: 'long', day: 'numeric' })}</Label><Title style={styles.greeting}>A good day to move, {user?.name?.split(' ')[0] || 'friend'}.</Title></View>
        <View style={[styles.avatar, { backgroundColor: colors.raised }]}><Text style={{ color: colors.accent, fontWeight: '800' }}>{user?.name?.[0]?.toUpperCase() || 'A'}</Text></View>
      </View>
      <Panel style={[styles.quoteCard, { borderColor: colors.line, backgroundColor: colors.panel }]}> 
        <Text style={[styles.heroEyebrow, { color: colors.muted }]}>TODAY’S NUDGE</Text>
        <Text style={[styles.quoteText, { color: colors.text }]}>{quote}</Text>
      </Panel>
      <View style={[styles.activityPanel, { backgroundColor: colors.hero }]}>
        <View style={styles.activityTop}><Text style={[styles.heroEyebrow, { color: colors.heroMuted }]}>LATEST DETECTION</Text><View style={[styles.liveDot, { backgroundColor: detectionIsStale ? colors.orange : colors.heroAccent }]} /><Text style={[styles.heroLive, { color: detectionIsStale ? colors.orange : colors.heroAccent }]}>{detectionIsStale ? 'STALE' : 'MODEL'}</Text></View>
        <Text style={[styles.activityName, { color: colors.heroAccent }]}>{current.data?.activity ? getDisplayActivityName(current.data.activity) : current.isLoading ? 'Listening…' : 'Ready when you are'}</Text>
        <View style={styles.activityFooter}>
          <Text style={{ color: colors.heroMuted }}>{activityNote}</Text>
          <Text style={[styles.heroArrow, { color: colors.heroAccent }]}>↗</Text>
        </View>
      </View>
      <View style={styles.sectionHeading}><Title style={styles.sectionTitle}>Today, at a glance</Title><Label>YOUR MOVEMENT</Label></View>
      <Panel style={styles.stepsPanel}>
        <View style={styles.goalHeader}><View><Label>STEPS</Label><Text style={[styles.stepsValue, { color: colors.text }]}>{stepCount.toLocaleString()}</Text></View><View style={styles.goalPercent}><Text style={[styles.goalPercentValue, { color: colors.accent }]}>{Math.round(progress * 100)}%</Text><Text style={{ color: colors.muted, fontSize: 11 }}>of daily goal</Text></View></View>
        <View style={[styles.progressTrack, { backgroundColor: colors.raised }]}><View style={[styles.progressFill, { backgroundColor: colors.accent, width: `${Math.max(progress * 100, stepCount ? 2 : 0)}%` }]} /></View>
        <Text style={[styles.stepsFootnote, { color: colors.muted }]}>{stepCount.toLocaleString()} of {goal.toLocaleString()} steps</Text>
      </Panel>
      <View style={styles.metricRow}>
        <MetricCard label="DISTANCE" value={`${(steps.data?.distance_km || 0).toFixed(2)} km`} note="estimated today" colors={colors} />
        <MetricCard label="ENERGY" value={`~${Math.round(steps.data?.calories_burned ?? estimatedMetrics.caloriesKcal)} kcal`} note="walking estimate" colors={colors} />
      </View>
      {pedometerStatus !== 'Step counter active' && <Text style={[styles.sensorStatus, { color: colors.orange }]}>{pedometerStatus}</Text>}
      {stepPermissionRequired && (
        <Pressable onPress={() => setPermissionRefreshToken((value) => value + 1)} style={[styles.permissionButton, { backgroundColor: colors.accent }]}>
          <Text style={[styles.primaryButtonText, { color: colors.bg }]}>Enable step tracking</Text>
        </Pressable>
      )}
      <View style={styles.sectionHeading}><Title style={styles.sectionTitle}>Movement mix</Title><Label>TODAY</Label></View>
      {today.isLoading ? <Loading colors={colors} /> : today.isError ? <InlineError text={getApiErrorMessage(today.error, "Today's activity is not available yet.")} colors={colors} /> : (
        <View style={styles.activityList}>
          {[
            { activity: 'Walking', seconds: today.data?.duration_seconds?.Walking || 0, color: colors.accent },
            { activity: 'Running', seconds: today.data?.duration_seconds?.Running || 0, color: colors.orange },
            { activity: 'Rest', seconds: (today.data?.duration_seconds?.Sitting || 0) + (today.data?.duration_seconds?.Standing || 0), color: colors.muted },
          ].map(({ activity, seconds, color: activityColor }) => {
            return <View key={activity} style={[styles.activityRow, { borderBottomColor: colors.line }]}><View style={[styles.activityDot, { backgroundColor: activityColor }]} /><Text style={[styles.activityLabel, { color: colors.text }]}>{activity}</Text><View style={styles.activityDuration}><View style={[styles.activityMiniTrack, { backgroundColor: colors.raised }]}><View style={[styles.activityMiniFill, { backgroundColor: activityColor, width: `${Math.min(seconds / 3600 * 100, 100)}%` }]} /></View><Text style={{ color: colors.muted, minWidth: 52, textAlign: 'right' }}>{Math.floor(seconds / 60)} min</Text></View></View>;
          })}
        </View>
      )}
      <Text style={[styles.disclaimer, { color: colors.muted }]}>Movement mix groups sitting and standing as rest. Distance and energy are rough estimates from steps and profile data, not medical measurements.</Text>
    </Page>
  );
}

function MetricCard({ label, value, note, accent, colors }) {
  return <Panel style={styles.metricCard}><Label>{label}</Label><Text style={[styles.metricValue, { color: accent ? colors.accent : colors.text }]}>{value}</Text><Text style={{ color: colors.muted, fontSize: 12 }}>{note}</Text></Panel>;
}

function HistoryScreen() {
  const colors = useColors();
  const activities = useQuery({ queryKey: ['activity', 'history'], queryFn: activityApi.history });
  const steps = useQuery({ queryKey: ['steps', 'history'], queryFn: stepsApi.history });
  return (
    <Page>
      <Label>YOUR RECORD</Label><Title>Activity history</Title>
      <View style={styles.sectionHeading}><Title style={styles.sectionTitle}>Activity sessions</Title><Label>RECENT</Label></View>
      {activities.isLoading ? <Loading colors={colors} /> : activities.isError ? <InlineError text="Activity history is unavailable." colors={colors} /> : activities.data?.length ? activities.data.map((row) => (
        <Panel key={row.id} style={styles.historyRow}>
          <View style={[styles.activityDot, { backgroundColor: colors.accent }]} />
          <View style={{ flex: 1 }}><Text style={[styles.activityLabel, { color: colors.text }]}>{getDisplayActivityName(row.activity)}</Text><Text style={{ color: colors.muted, marginTop: 4 }}>{new Date(row.start_time).toLocaleString()}</Text></View>
          <Text style={{ color: colors.muted }}>{Math.round(row.duration_seconds / 60)} min</Text>
        </Panel>
      )) : <EmptyState title="A fresh start" copy="Your activity sessions will collect here as you move." colors={colors} />}
      <View style={styles.sectionHeading}><Title style={styles.sectionTitle}>Daily steps</Title><Label>RECENT DAYS</Label></View>
      {steps.isLoading ? <Loading colors={colors} /> : steps.isError ? <InlineError text="Step history is unavailable." colors={colors} /> : steps.data?.length ? steps.data.slice().reverse().map((row) => (
        <View key={row.id} style={[styles.stepHistoryRow, { borderBottomColor: colors.line }]}><Text style={{ color: colors.text }}>{new Date(`${row.log_date}T12:00:00`).toLocaleDateString(undefined, { weekday: 'short', month: 'short', day: 'numeric' })}</Text><Text style={{ color: colors.accent, fontWeight: '800' }}>{row.steps.toLocaleString()} steps</Text></View>
      )) : <EmptyState title="No step history yet" copy="Your daily totals will appear here." colors={colors} />}
    </Page>
  );
}

function AnalyticsScreen() {
  const colors = useColors();
  const weekly = useQuery({ queryKey: ['analytics', 'weekly'], queryFn: analyticsApi.weekly });
  const monthly = useQuery({ queryKey: ['analytics', 'monthly'], queryFn: analyticsApi.monthly });
  const goals = useQuery({ queryKey: ['goals'], queryFn: goalsApi.get });
  const data = weekly.data?.days || [];
  const weeklyGoal = Number(goals.data?.daily_step_goal || STARTER_DAILY_STEP_GOAL);
  const averageStepsPerDay = Math.round((weekly.data?.totals?.total_steps || 0) / 7);
  const goalDays = data.filter((day) => day.total_steps >= weeklyGoal).length;
  const chartConfig = { backgroundGradientFrom: colors.panel, backgroundGradientTo: colors.panel, decimalPlaces: 0, color: () => colors.accent, labelColor: () => colors.muted, propsForBackgroundLines: { stroke: colors.line }, propsForDots: { r: '3', strokeWidth: '1', stroke: colors.accent } };
  return (
    <Page>
      <Label>YOUR PATTERNS</Label><Title>Weekly insights</Title>
      {weekly.isLoading ? <Loading colors={colors} /> : weekly.isError ? <InlineError text="Analytics are unavailable." colors={colors} /> : (
        <>
          <View style={styles.sectionHeading}><Title style={styles.sectionTitle}>Steps this week</Title><Label>7 DAYS</Label></View>
          <Panel style={styles.chartPanel}>
            {data.length ? <LineChart data={{ labels: data.map((day) => new Date(`${day.summary_date}T12:00:00`).toLocaleDateString(undefined, { weekday: 'narrow' })), datasets: [{ data: data.map((day) => day.total_steps) }] }} width={Dimensions.get('window').width - 56} height={200} chartConfig={chartConfig} bezier withDots withInnerLines /> : <EmptyState title="No trend data yet" copy="Step trends appear after your first tracked days." colors={colors} />}
          </Panel>
          <View style={styles.metricRow}>
            <MetricCard label="WEEKLY STEPS" value={(weekly.data?.totals?.total_steps || 0).toLocaleString()} note="steps recorded" colors={colors} />
            <MetricCard label="DISTANCE" value={`${(weekly.data?.totals?.total_distance || 0).toFixed(1)} km`} note="this week" colors={colors} />
          </View>
          <Panel style={styles.weekRecapPanel}>
            <Label>YOUR WEEK IN REVIEW</Label>
            <Text style={[styles.weekRecapTitle, { color: colors.text }]}>{goalDays ? `${goalDays} day${goalDays === 1 ? '' : 's'} at your goal` : 'A week to build from'}</Text>
            <Text style={{ color: colors.muted, lineHeight: 20 }}>You averaged {averageStepsPerDay.toLocaleString()} steps a day and reached your {weeklyGoal.toLocaleString()}-step target on {goalDays} of 7 days.</Text>
          </Panel>
          <View style={styles.sectionHeading}><Title style={styles.sectionTitle}>Activity mix</Title><Label>MINUTES</Label></View>
          <Panel style={styles.chartPanel}>
            {data.length ? <BarChart data={{ labels: ['Walk', 'Run', 'Rest'], datasets: [{ data: ['walking_minutes', 'running_minutes'].map((key) => data.reduce((sum, day) => sum + (day[key] || 0), 0)).concat(data.reduce((sum, day) => sum + (day.sitting_minutes || 0) + (day.standing_minutes || 0), 0)) }] }} width={Dimensions.get('window').width - 56} height={210} chartConfig={chartConfig} fromZero showValuesOnTopOfBars /> : <EmptyState title="No activity mix yet" copy="Activity minutes appear after classification is active." colors={colors} />}
          </Panel>
          <View style={styles.sectionHeading}><Title style={styles.sectionTitle}>This month</Title><Label>MONTH TO DATE</Label></View>
          {monthly.isLoading ? <Loading colors={colors} /> : monthly.isError ? <InlineError text="Monthly totals are unavailable." colors={colors} /> : <Panel style={styles.monthPanel}><Text style={[styles.metricValue, { color: colors.text }]}>{(monthly.data?.totals?.total_steps || 0).toLocaleString()}</Text><Label>TOTAL STEPS THIS MONTH</Label><Text style={{ color: colors.muted, marginTop: 10 }}>{(monthly.data?.totals?.total_distance || 0).toFixed(1)} km travelled</Text></Panel>}
        </>
      )}
    </Page>
  );
}

function GoalsScreen() {
  const colors = useColors();
  const client = useQueryClient();
  const user = useAppStore((state) => state.user);
  const goals = useQuery({ queryKey: ['goals'], queryFn: goalsApi.get });
  const steps = useQuery({ queryKey: ['steps', 'today'], queryFn: stepsApi.today });
  const stepHistory = useQuery({ queryKey: ['steps', 'history'], queryFn: stepsApi.history, staleTime: 300000 });
  const recommendation = getStepGoalRecommendation(stepHistory.data || [], new Date(), user || {});
  const [daily, setDaily] = useState(String(STARTER_DAILY_STEP_GOAL));
  const [weekly, setWeekly] = useState('3');
  const [distance, setDistance] = useState('50');
  useEffect(() => {
    if (!goals.data) return;
    setDaily(String(goals.data.daily_step_goal));
    setWeekly(String(goals.data.weekly_running_goal));
    setDistance(String(goals.data.monthly_distance_goal));
  }, [goals.data]);
  const save = useMutation({
    mutationFn: () => goalsApi.save({ daily_step_goal: Number(daily), weekly_running_goal: Number(weekly), monthly_distance_goal: Number(distance) }),
    onSuccess: () => client.invalidateQueries({ queryKey: ['goals'] }),
    onError: () => Alert.alert('Could not save', 'Check your connection and try again.'),
  });
  const stepProgress = Math.min((steps.data?.steps || 0) / Number(daily || 1), 1);
  return (
    <Page>
      <Label>SMALL TARGETS, STEADY MOMENTUM</Label><Title>Goals</Title>
      <Panel style={[styles.quoteCard, { borderColor: colors.line, backgroundColor: colors.panel }]}> 
        <Text style={[styles.heroEyebrow, { color: colors.muted }]}>{recommendation.isPersonalized ? 'RECENT ACTIVITY SUGGESTION' : 'STARTER TARGET'}</Text>
        <Text style={[styles.quoteText, { color: colors.text }]}>{recommendation.isPersonalized
          ? `Your ${recommendation.sampleDays}-day average is ${recommendation.averageSteps.toLocaleString()} steps. A gradual next target is ${recommendation.dailyStepGoal.toLocaleString()}.`
          : `Your starting target uses your profile. After 3 tracked days, BFit can refine it using your recent average.`}</Text>
        {Number(daily) !== recommendation.dailyStepGoal && (
          <Pressable accessibilityRole="button" onPress={() => setDaily(String(recommendation.dailyStepGoal))} style={[styles.suggestionButton, { borderColor: colors.line }]}>
            <Text style={{ color: colors.accent, fontWeight: '700' }}>Use {recommendation.dailyStepGoal.toLocaleString()} steps</Text>
          </Pressable>
        )}
      </Panel>
      <Panel style={styles.progressPanel}>
        <View style={styles.goalHeader}><View><Label>TODAY'S STEPS</Label><Text style={[styles.metricValue, { color: colors.text }]}>{(steps.data?.steps || 0).toLocaleString()} <Text style={{ fontSize: 14, color: colors.muted }}>/ {Number(daily || 0).toLocaleString()}</Text></Text></View><Text style={{ color: colors.accent, fontWeight: '800' }}>{Math.round(stepProgress * 100)}%</Text></View>
        <View style={[styles.progressTrack, { backgroundColor: colors.raised }]}><View style={[styles.progressFill, { backgroundColor: colors.accent, width: `${stepProgress * 100}%` }]} /></View>
      </Panel>
      <View style={styles.sectionHeading}><Title style={styles.sectionTitle}>Your targets</Title><Label>EDIT GOALS</Label></View>
      <GoalInput label="Daily steps" value={daily} suffix="steps / day" onChangeText={setDaily} colors={colors} />
      <GoalInput label="Weekly runs" value={weekly} suffix="sessions / week" onChangeText={setWeekly} colors={colors} />
      <GoalInput label="Monthly distance" value={distance} suffix="km / month" onChangeText={setDistance} colors={colors} />
      <Pressable disabled={save.isPending || !Number(daily)} onPress={() => save.mutate()} style={[styles.primaryButton, { backgroundColor: colors.accent, marginTop: 24 }]}>
        {save.isPending ? <ActivityIndicator color={colors.bg} /> : <Text style={[styles.primaryButtonText, { color: colors.bg }]}>Save goals  →</Text>}
      </Pressable>
      {save.isSuccess && <Text style={{ color: colors.accent, marginTop: 12 }}>Goals updated.</Text>}
    </Page>
  );
}

function GoalInput({ label, suffix, colors, ...props }) {
  return <Panel style={styles.goalInputPanel}><View style={{ flex: 1 }}><Text style={[styles.activityLabel, { color: colors.text }]}>{label}</Text><Text style={{ color: colors.muted, marginTop: 4 }}>{suffix}</Text></View><TextInput keyboardType="numeric" selectTextOnFocus style={[styles.goalInput, { color: colors.text, borderColor: colors.line }]} {...props} /></Panel>;
}

function ProfileScreen() {
  const colors = useColors();
  const user = useAppStore((state) => state.user);
  const setUser = useAppStore((state) => state.setUser);
  const toggleTheme = useAppStore((state) => state.toggleTheme);
  const clearUser = useAppStore((state) => state.clearUser);
  const client = useQueryClient();
  const [isEditingProfile, setIsEditingProfile] = useState(false);
  const [age, setAge] = useState(String(user?.age || ''));
  const [height, setHeight] = useState(String(user?.height_cm || ''));
  const [weight, setWeight] = useState(String(user?.weight_kg || ''));
  const [gender, setGender] = useState(String(user?.gender || ''));
  const [savingProfile, setSavingProfile] = useState(false);
  const [reminderEnabled, setReminderEnabled] = useState(false);
  const [reminderHour, setReminderHour] = useState('19');
  const [reminderMinute, setReminderMinute] = useState('00');
  const [savingReminder, setSavingReminder] = useState(false);
  const reminderSupported = Platform.OS !== 'android' || !isRunningInExpoGo();
  const goals = useQuery({ queryKey: ['goals'], queryFn: goalsApi.get });
  useEffect(() => {
    setAge(String(user?.age || ''));
    setHeight(String(user?.height_cm || ''));
    setWeight(String(user?.weight_kg || ''));
    setGender(String(user?.gender || ''));
  }, [user?.age, user?.height_cm, user?.weight_kg, user?.gender]);
  useEffect(() => {
    let active = true;
    getMovementReminderSettings().then((settings) => {
      if (!active) return;
      setReminderEnabled(settings.enabled);
      setReminderHour(String(settings.hour).padStart(2, '0'));
      setReminderMinute(String(settings.minute).padStart(2, '0'));
    });
    return () => { active = false; };
  }, []);
  const updateReminder = async (enabled) => {
    const wasEnabled = reminderEnabled;
    setSavingReminder(true);
    try {
      if (enabled) {
        const result = await scheduleMovementReminder(Number(reminderHour), Number(reminderMinute));
        Alert.alert(
          result.previousReminderMayRemain ? 'Reminder updated with a warning' : 'Reminder updated',
          result.previousReminderMayRemain
            ? `Your reminder is set for ${reminderHour}:${reminderMinute}, but the previous reminder could not be removed and may also fire.`
            : `Your daily movement reminder is set for ${reminderHour}:${reminderMinute}.`,
        );
      } else {
        await cancelMovementReminder();
        Alert.alert('Reminder turned off', 'Your daily movement reminder has been cancelled.');
      }
      setReminderEnabled(enabled);
    } catch (error) {
      Alert.alert('Reminder not updated', error.message || 'Check notification permission and try again.');
      setReminderEnabled(wasEnabled);
    } finally {
      setSavingReminder(false);
    }
  };
  const saveProfile = async () => {
    setSavingProfile(true);
    try {
      const updatedUser = await authApi.updateProfile({
        age: Number(age),
        height_cm: Number(height),
        weight_kg: Number(weight),
        gender: gender || null,
      });
      setUser(updatedUser);
      try {
        const [history, savedGoals] = await Promise.all([stepsApi.history(), goalsApi.get()]);
        const recommendation = getStepGoalRecommendation(history, new Date(), updatedUser);
        await goalsApi.save({
          daily_step_goal: recommendation.dailyStepGoal,
          weekly_running_goal: savedGoals.weekly_running_goal,
          monthly_distance_goal: savedGoals.monthly_distance_goal,
        });
        await client.invalidateQueries({ queryKey: ['goals'] });
      } catch {
        Alert.alert('Profile saved', 'Your profile was saved, but the personalized step goal could not be updated. Check your connection and try again.');
      }
      setIsEditingProfile(false);
    } catch (error) {
      const detail = error.response?.data?.detail;
      Alert.alert('Could not save profile', typeof detail === 'string' ? detail : 'Check the measurements and try again.');
    } finally {
      setSavingProfile(false);
    }
  };
  const signOut = async () => {
    await clearAccessToken();
    clearUser();
    client.clear();
  };
  return (
    <Page>
      <Label>YOUR ACCOUNT</Label><Title>Profile</Title>
      <Panel style={styles.profilePanel}>
        <View style={[styles.profileAvatar, { backgroundColor: colors.raised }]}><Text style={{ color: colors.accent, fontSize: 26, fontWeight: '800' }}>{user?.name?.[0]?.toUpperCase() || 'A'}</Text></View>
        <Text style={[styles.profileName, { color: colors.text }]}>{user?.name}</Text>
        <Text style={{ color: colors.muted }}>{user?.email}</Text>
      </Panel>
      <View style={styles.sectionHeading}><Title style={styles.sectionTitle}>Personal details</Title>{!isEditingProfile && <Pressable onPress={() => setIsEditingProfile(true)}><Text style={{ color: colors.accent, fontWeight: '700' }}>Edit</Text></Pressable>}</View>
      {isEditingProfile ? (
        <>
          <View style={styles.fieldRow}>
            <Field label="AGE" value={age} onChangeText={setAge} keyboardType="numeric" containerStyle={styles.fieldCompact} colors={colors} />
            <Field label="HEIGHT (cm)" value={height} onChangeText={setHeight} keyboardType="numeric" containerStyle={styles.fieldCompact} colors={colors} />
          </View>
          <Field label="WEIGHT (kg)" value={weight} onChangeText={setWeight} keyboardType="numeric" colors={colors} />
          <Text style={[styles.label, { marginTop: 10, marginBottom: 8, color: colors.muted }]}>GENDER</Text>
          <GenderPicker value={gender} onChange={setGender} colors={colors} />
          <View style={styles.profileActions}>
            <Pressable disabled={savingProfile} onPress={() => setIsEditingProfile(false)} style={[styles.cancelButton, { borderColor: colors.line }]}><Text style={{ color: colors.muted, fontWeight: '700' }}>Cancel</Text></Pressable>
            <Pressable disabled={savingProfile || !age || !height || !weight} onPress={saveProfile} style={[styles.saveProfileButton, { backgroundColor: colors.accent, opacity: savingProfile || !age || !height || !weight ? 0.6 : 1 }]}>
              {savingProfile ? <ActivityIndicator color={colors.bg} /> : <Text style={[styles.primaryButtonText, { color: colors.bg }]}>Save details</Text>}
            </Pressable>
          </View>
        </>
      ) : (
        <>
          <InfoRow label="Age" value={user?.age ? `${user.age} years` : 'Not provided'} colors={colors} />
          <InfoRow label="Height" value={user?.height_cm ? `${user.height_cm} cm` : 'Not provided'} colors={colors} />
          <InfoRow label="Weight" value={user?.weight_kg ? `${user.weight_kg} kg` : 'Not provided'} colors={colors} />
          <InfoRow label="Gender" value={user?.gender || 'Not provided'} colors={colors} />
        </>
      )}
          <InfoRow label="Daily target" value={goals.data ? `${goals.data.daily_step_goal.toLocaleString()} steps` : 'Not set'} colors={colors} />
      <View style={styles.sectionHeading}><Title style={styles.sectionTitle}>Preferences</Title></View>
      <Pressable onPress={toggleTheme} style={[styles.preferenceRow, { borderBottomColor: colors.line }]}><Text style={{ color: colors.text }}>Appearance</Text><Text style={{ color: colors.accent, fontWeight: '700' }}>{useAppStore.getState().isDark ? 'Dark' : 'Light'}  ↔</Text></Pressable>
      {Platform.OS !== 'web' && reminderSupported && (
        <View style={[styles.reminderPanel, { backgroundColor: colors.panel, borderColor: colors.line }]}> 
          <View style={styles.reminderHeader}>
            <View style={{ flex: 1, paddingRight: 12 }}>
              <Text style={[styles.activityLabel, { color: colors.text }]}>Daily move reminder</Text>
              <Text style={{ color: colors.muted, fontSize: 12, lineHeight: 18, marginTop: 4 }}>A quiet nudge at a time you choose.</Text>
            </View>
            <Switch
              accessibilityLabel="Daily move reminder"
              value={reminderEnabled}
              disabled={savingReminder}
              onValueChange={updateReminder}
              trackColor={{ false: colors.raised, true: colors.accent }}
              thumbColor={colors.panel}
            />
          </View>
          {reminderEnabled && (
            <View style={styles.reminderTimeRow}>
              <Text style={{ color: colors.muted }}>TIME</Text>
              <TextInput value={reminderHour} onChangeText={(value) => setReminderHour(value.replace(/\D/g, '').slice(0, 2))} keyboardType="number-pad" maxLength={2} style={[styles.reminderTimeInput, { color: colors.text, borderColor: colors.line }]} />
              <Text style={{ color: colors.text, fontWeight: '700' }}>:</Text>
              <TextInput value={reminderMinute} onChangeText={(value) => setReminderMinute(value.replace(/\D/g, '').slice(0, 2))} keyboardType="number-pad" maxLength={2} style={[styles.reminderTimeInput, { color: colors.text, borderColor: colors.line }]} />
              <Pressable disabled={savingReminder || reminderHour.length !== 2 || reminderMinute.length !== 2} onPress={() => updateReminder(true)} style={[styles.reminderSaveButton, { backgroundColor: colors.accent, opacity: savingReminder || reminderHour.length !== 2 || reminderMinute.length !== 2 ? 0.5 : 1 }]}>
                <Text style={{ color: colors.bg, fontWeight: '700' }}>Update</Text>
              </Pressable>
            </View>
          )}
          {reminderEnabled && (
            <Text style={{ color: colors.muted, fontSize: 12, lineHeight: 18, marginTop: 10 }}>
              Repeats once each day. If today’s time has passed, it will notify tomorrow. Android may deliver it slightly late to save battery.
            </Text>
          )}
        </View>
      )}
      {Platform.OS === 'android' && !reminderSupported && (
        <View style={[styles.reminderPanel, { backgroundColor: colors.panel, borderColor: colors.line }]}> 
          <Text style={[styles.activityLabel, { color: colors.text }]}>Daily reminders need BFit installed</Text>
          <Text style={{ color: colors.muted, fontSize: 12, lineHeight: 18, marginTop: 5 }}>Expo Go on Android does not provide the notifications module. Install a BFit development build to enable scheduled reminders.</Text>
        </View>
      )}
      <View style={styles.sectionHeading}><Title style={styles.sectionTitle}>Your goals</Title></View>
      {goals.data ? <InfoRow label="Daily step goal" value={`${goals.data.daily_step_goal.toLocaleString()} steps`} colors={colors} /> : <Loading colors={colors} />}
      <Pressable onPress={signOut} style={[styles.signOutButton, { borderColor: colors.line }]}><Text style={{ color: colors.red, fontWeight: '700' }}>Sign out</Text></Pressable>
    </Page>
  );
}

function OnboardingScreen({ onComplete }) {
  const colors = useColors();
  const insets = useSafeAreaInsets();
  const client = useQueryClient();
  const user = useAppStore((state) => state.user);
  const setUser = useAppStore((state) => state.setUser);
  const [age, setAge] = useState(String(user?.age || ''));
  const [height, setHeight] = useState(String(user?.height_cm || ''));
  const [weight, setWeight] = useState(String(user?.weight_kg || ''));
  const [gender, setGender] = useState(String(user?.gender || ''));
  const [saving, setSaving] = useState(false);
  const stepHistory = useQuery({ queryKey: ['steps', 'history'], queryFn: stepsApi.history, staleTime: 300000 });
  const recommendation = getStepGoalRecommendation(stepHistory.data || [], new Date(), {
    ...user,
    age: Number(age) || user?.age,
    height_cm: Number(height) || user?.height_cm,
    weight_kg: Number(weight) || user?.weight_kg,
    gender,
  });

  const complete = async () => {
    if (!age || !height || !weight) return;
    setSaving(true);
    try {
      const profile = await authApi.updateProfile({
        age: Number(age),
        height_cm: Number(height),
        weight_kg: Number(weight),
        gender: gender || null,
      });
      const profileRecommendation = getStepGoalRecommendation(stepHistory.data || [], new Date(), profile);
      const goalPlan = getGoalSummary(profileRecommendation.dailyStepGoal);
      await goalsApi.save({
        daily_step_goal: goalPlan.daily_step_goal,
        weekly_running_goal: goalPlan.weekly_running_goal,
        monthly_distance_goal: goalPlan.monthly_distance_goal,
      });
      await client.invalidateQueries({ queryKey: ['goals'] });
      setUser(profile);
      onComplete?.();
    } catch (error) {
      const detail = error.response?.data?.detail;
      Alert.alert('Profile setup failed', typeof detail === 'string' ? detail : error.message || 'Your measurements and goal could not be saved. Please try again.');
    } finally {
      setSaving(false);
    }
  };

  return (
    <ScrollView
      style={{ backgroundColor: colors.bg }}
      contentContainerStyle={[styles.onboardingWrap, { paddingTop: 24 + insets.top, paddingBottom: 24 + insets.bottom }]}
      keyboardShouldPersistTaps="handled"
    >
      <View style={[styles.onboardingCard, { backgroundColor: colors.panel, borderColor: colors.line }]}> 
        <Image source={require('./assets/icon.png')} style={styles.onboardingIcon} accessibilityLabel="BFit app icon" />
        <Text style={[styles.onboardingTitle, { color: colors.text }]}>Personalize your plan</Text>
        <Text style={[styles.onboardingCopy, { color: colors.muted }]}>Your profile helps estimate walking distance and energy. Your step target starts gently and can adjust as BFit learns your routine.</Text>
        <View style={styles.fieldRow}>
          <Field label="AGE" value={age} onChangeText={setAge} keyboardType="numeric" containerStyle={styles.fieldCompact} colors={colors} />
          <Field label="HEIGHT (cm)" value={height} onChangeText={setHeight} keyboardType="numeric" containerStyle={styles.fieldCompact} colors={colors} />
        </View>
        <Field label="WEIGHT (kg)" value={weight} onChangeText={setWeight} keyboardType="numeric" colors={colors} />
        <Text style={[styles.label, { alignSelf: 'flex-start', marginTop: 12, marginBottom: 8, color: colors.muted }]}>GENDER (OPTIONAL)</Text>
        <GenderPicker value={gender} onChange={setGender} colors={colors} />
        <View style={[styles.goalPreview, { backgroundColor: colors.raised }]}> 
          <Label>{recommendation.isPersonalized ? 'BASED ON RECENT STEPS' : 'YOUR STARTING TARGET'}</Label>
          <Text style={[styles.metricValue, { color: colors.text }]}>{recommendation.dailyStepGoal.toLocaleString()} <Text style={{ fontSize: 14, color: colors.muted }}>steps/day</Text></Text>
          <Text style={{ color: colors.muted, fontSize: 12 }}>{recommendation.isPersonalized
            ? `From an average of ${recommendation.averageSteps.toLocaleString()} steps across ${recommendation.sampleDays} tracked days.`
            : 'After 3 tracked days, we can suggest a gradual target from your average.'}</Text>
        </View>
        <Pressable disabled={saving || !age || !height || !weight} onPress={complete} style={[styles.primaryButton, styles.onboardingButton, { backgroundColor: colors.accent, opacity: saving ? 0.65 : 1 }]}> 
          {saving ? <ActivityIndicator color={colors.bg} /> : <Text style={[styles.primaryButtonText, styles.onboardingButtonText, { color: colors.bg }]}>Set my goal  →</Text>}
        </Pressable>
      </View>
    </ScrollView>
  );
}

function InfoRow({ label, value, colors }) {
  return <View style={[styles.infoRow, { borderBottomColor: colors.line }]}><Text style={{ color: colors.muted }}>{label}</Text><Text style={{ color: colors.text, fontWeight: '600' }}>{value}</Text></View>;
}

function Loading({ colors }) {
  return <View style={styles.statusBox}><ActivityIndicator color={colors.accent} /><Text style={{ color: colors.muted, marginTop: 12 }}>Loading your data…</Text></View>;
}

function InlineError({ text, colors }) {
  return <Text style={{ color: colors.orange, paddingVertical: 16 }}>{text}</Text>;
}

function getApiErrorMessage(error, fallback) {
  const detail = error?.response?.data?.detail;
  if (typeof detail === 'string') return detail;
  if (error?.response?.status) return `${fallback} (server error ${error.response.status})`;
  return fallback;
}

function EmptyState({ title, copy, colors }) {
  return <View style={styles.emptyState}><Text style={[styles.activityLabel, { color: colors.text }]}>{title}</Text><Text style={{ color: colors.muted, lineHeight: 21, marginTop: 6 }}>{copy}</Text></View>;
}

function MainTabs() {
  const colors = useColors();
  const insets = useSafeAreaInsets();
  const icons = { Home: '⌂', History: '≋', Insights: '↗', Goals: '◎', Profile: '○' };
  return (
    <Tabs.Navigator screenOptions={({ route }) => ({
      headerShown: false,
      tabBarStyle: { backgroundColor: colors.panel, borderTopColor: colors.line, borderTopWidth: StyleSheet.hairlineWidth, height: 72 + insets.bottom, paddingTop: 8, paddingBottom: 10 + insets.bottom },
      tabBarActiveTintColor: colors.accent,
      tabBarInactiveTintColor: colors.muted,
      tabBarLabelStyle: { fontSize: 10, fontWeight: '600', marginTop: 2 },
      tabBarIcon: ({ color }) => <Text style={{ color, fontSize: 19, lineHeight: 22 }}>{icons[route.name]}</Text>,
    })}>
      <Tabs.Screen name="Home" component={HomeScreen} />
      <Tabs.Screen name="History" component={HistoryScreen} />
      <Tabs.Screen name="Insights" component={AnalyticsScreen} />
      <Tabs.Screen name="Goals" component={GoalsScreen} />
      <Tabs.Screen name="Profile" component={ProfileScreen} />
    </Tabs.Navigator>
  );
}

function AppContent() {
  const colors = useColors();
  const isDark = useAppStore((state) => state.isDark);
  const user = useAppStore((state) => state.user);
  const setUser = useAppStore((state) => state.setUser);
  const [booting, setBooting] = useState(true);
  const [profileSetupOpen, setProfileSetupOpen] = useState(false);
  useEffect(() => {
    let mounted = true;
    getAccessToken()
      .then((token) => token ? authApi.profile() : null)
      .then((profile) => { if (mounted && profile) setUser(profile); })
      .catch(async (error) => {
        if (error.response?.status === 401) await clearAccessToken();
      })
      .finally(() => { if (mounted) setBooting(false); });
    return () => { mounted = false; };
  }, [setUser]);
  useEffect(() => {
    if (!user || (Platform.OS === 'android' && isRunningInExpoGo())) return undefined;
    let mounted = true;
    configureMovementNotifications().catch((error) => {
      if (mounted) Alert.alert('Notifications unavailable', error.message || 'Restart BFit and check notification settings.');
    });
    return () => { mounted = false; };
  }, [user]);
  useEffect(() => {
    if (user && (!user.age || !user.height_cm || !user.weight_kg)) {
      setProfileSetupOpen(true);
    } else {
      setProfileSetupOpen(false);
    }
  }, [user]);
  const insets = useSafeAreaInsets();
  if (booting) return <View style={[styles.boot, { backgroundColor: colors.bg, paddingTop: insets.top }]}><BrandMark size={76} cutout={colors.bg} /><ActivityIndicator color={colors.accent} style={{ marginTop: 22 }} /><Text style={[styles.loadingTagline, { color: colors.muted }]}>BALANCED TODAY · BETTER TOMORROW</Text></View>;
  const baseTheme = isDark ? DarkTheme : DefaultTheme;
  const baseFonts = baseTheme.fonts || {};
  if (user && profileSetupOpen) {
    return (
      <NavigationContainer theme={{
        ...baseTheme,
        fonts: {
          regular: baseFonts.regular || {},
          medium: baseFonts.medium || { fontWeight: '500' },
          bold: baseFonts.bold || { fontWeight: '600' },
          heavy: baseFonts.heavy || { fontWeight: '700' },
        },
        colors: {
          ...baseTheme.colors,
          primary: colors.accent,
          background: colors.bg,
          card: colors.panel,
          text: colors.text,
          border: colors.line,
          notification: colors.orange,
        },
      }}>
        <OnboardingScreen onComplete={() => setProfileSetupOpen(false)} />
      </NavigationContainer>
    );
  }
  return (
    <NavigationContainer theme={{
      ...baseTheme,
      fonts: {
        regular: baseFonts.regular || {},
        medium: baseFonts.medium || { fontWeight: '500' },
        bold: baseFonts.bold || { fontWeight: '600' },
        heavy: baseFonts.heavy || { fontWeight: '700' },
      },
      colors: {
        ...baseTheme.colors,
        primary: colors.accent,
        background: colors.bg,
        card: colors.panel,
        text: colors.text,
        border: colors.line,
        notification: colors.orange,
      },
    }}>
      {user ? <MainTabs /> : <AuthScreen />}
    </NavigationContainer>
  );
}

export default function App() {
  const isDark = useAppStore((state) => state.isDark);
  return (
    <QueryClientProvider client={queryClient}>
      <SafeAreaProvider>
        <StatusBar style={isDark ? 'light' : 'dark'} />
        <AppContent />
      </SafeAreaProvider>
    </QueryClientProvider>
  );
}

const styles = StyleSheet.create({
  page: { paddingHorizontal: 23, paddingTop: 16, paddingBottom: 42 },
  authPage: { flexGrow: 1, paddingHorizontal: 28, paddingTop: 20, paddingBottom: 34 },
  quoteCard: { borderRadius: 22, borderWidth: 1, padding: 18, marginBottom: 18 },
  quoteText: { fontSize: 17, fontWeight: '600', lineHeight: 24, marginTop: 10 },
  permissionButton: { minHeight: 48, borderRadius: 12, alignItems: 'center', justifyContent: 'center', marginTop: 12, marginBottom: 8, shadowColor: '#000', shadowOpacity: 0.08, shadowRadius: 10, shadowOffset: { width: 0, height: 5 }, elevation: 3 },
  brandLockup: { flexDirection: 'row', alignItems: 'center', gap: 13 },
  brandLockupText: { justifyContent: 'center' },
  brandWordmark: { fontSize: 34, fontWeight: '700', lineHeight: 38 },
  brandTagline: { fontSize: 8, letterSpacing: 2.4, lineHeight: 14 },
  loadingTagline: { fontSize: 9, letterSpacing: 2, marginTop: 16 },
  authEyebrow: { marginTop: 48 },
  authTitle: { fontFamily: 'serif', fontSize: 39, fontWeight: '400', lineHeight: 46, marginTop: 15 },
  authCopy: { fontSize: 15, lineHeight: 24, marginTop: 14, marginBottom: 24 },
  title: { fontFamily: 'serif', fontSize: 28, fontWeight: '400', lineHeight: 35 },
  label: { fontSize: 10, fontWeight: '700', letterSpacing: 1.1 },
  field: { marginTop: 17, width: '100%' },
  fieldCompact: { flex: 1, minWidth: 0 },
  input: { height: 54, borderWidth: 1, borderRadius: 12, marginTop: 8, paddingHorizontal: 15, fontSize: 15 },
  primaryButton: { minHeight: 54, borderRadius: 14, alignItems: 'center', justifyContent: 'center', marginTop: 24, shadowColor: '#1F291F', shadowOpacity: 0.1, shadowRadius: 12, shadowOffset: { width: 0, height: 8 }, elevation: 4 },
  primaryButtonText: { fontSize: 15, fontWeight: '800' },
  textButton: { alignItems: 'center', paddingVertical: 20 },
  headerRow: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', marginBottom: 22 },
  greeting: { fontSize: 22, lineHeight: 29, marginTop: 7, maxWidth: 280 },
  avatar: { width: 42, height: 42, borderRadius: 21, alignItems: 'center', justifyContent: 'center' },
  panel: { borderRadius: 18, borderWidth: StyleSheet.hairlineWidth, padding: 17, shadowColor: '#1F291F', shadowOpacity: 0.06, shadowRadius: 14, shadowOffset: { width: 0, height: 6 }, elevation: 2 },
  activityPanel: { minHeight: 196, borderRadius: 24, justifyContent: 'space-between', padding: 22, shadowColor: '#1F291F', shadowOpacity: 0.12, shadowRadius: 18, shadowOffset: { width: 0, height: 10 }, elevation: 4 },
  activityTop: { flexDirection: 'row', alignItems: 'center', gap: 9 },
  heroEyebrow: { fontSize: 10, fontWeight: '700', letterSpacing: 1.2 },
  heroLive: { fontSize: 9, fontWeight: '700', letterSpacing: 1.1 },
  heroArrow: { fontSize: 23, fontWeight: '400' },
  liveDot: { width: 6, height: 6, borderRadius: 3, marginLeft: 'auto' },
  activityName: { fontFamily: 'serif', fontSize: 38, fontWeight: '400', marginTop: 22 },
  activityFooter: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', gap: 8, marginTop: 18 },
  pill: { paddingHorizontal: 9, paddingVertical: 6, borderRadius: 20 },
  sectionHeading: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', marginTop: 29, marginBottom: 13 },
  sectionTitle: { fontFamily: 'serif', fontSize: 19, lineHeight: 26 },
  metricRow: { flexDirection: 'row', gap: 12, marginTop: 12 },
  metricCard: { flex: 1, minHeight: 100, justifyContent: 'space-between', padding: 15 },
  metricValue: { fontSize: 23, fontWeight: '600', marginVertical: 8 },
  stepsPanel: { borderRadius: 16, padding: 19 },
  stepsValue: { fontFamily: 'serif', fontSize: 39, lineHeight: 47, marginTop: 7 },
  goalPercent: { alignItems: 'flex-end', justifyContent: 'center' },
  goalPercentValue: { fontFamily: 'serif', fontSize: 25, fontWeight: '400' },
  stepsFootnote: { fontSize: 12, marginTop: 10 },
  sensorStatus: { fontSize: 12, lineHeight: 18, marginTop: 10 },
  goalPanel: { marginTop: 12 },
  goalHeader: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center' },
  goalNumbers: { fontSize: 23, fontWeight: '600', marginTop: 7 },
  progressTrack: { height: 8, borderRadius: 8, overflow: 'hidden', marginTop: 17 },
  progressFill: { height: '100%', borderRadius: 8 },
  activityList: { paddingHorizontal: 2 },
  activityRow: { minHeight: 58, flexDirection: 'row', alignItems: 'center', borderBottomWidth: StyleSheet.hairlineWidth, gap: 12 },
  activityDot: { width: 9, height: 9, borderRadius: 5 },
  activityLabel: { fontSize: 14, fontWeight: '500' },
  activityDuration: { flex: 1, flexDirection: 'row', alignItems: 'center', justifyContent: 'flex-end', gap: 10 },
  activityMiniTrack: { width: 68, height: 4, borderRadius: 4, overflow: 'hidden' },
  activityMiniFill: { height: '100%', borderRadius: 4 },
  disclaimer: { fontSize: 12, lineHeight: 19, marginTop: 20 },
  historyRow: { flexDirection: 'row', alignItems: 'center', gap: 12, marginBottom: 9, minHeight: 76 },
  stepHistoryRow: { height: 48, flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', borderBottomWidth: StyleSheet.hairlineWidth },
  chartPanel: { alignItems: 'center', paddingHorizontal: 4, paddingVertical: 12, minHeight: 160 },
  monthPanel: { padding: 18 },
  progressPanel: { marginTop: 22 },
  goalInputPanel: { minHeight: 72, flexDirection: 'row', alignItems: 'center', marginTop: 9 },
  goalInput: { width: 88, borderBottomWidth: 1, padding: 7, textAlign: 'right', fontSize: 17, fontWeight: '700' },
  profilePanel: { alignItems: 'center', marginTop: 18, paddingVertical: 25 },
  genderPicker: { width: '100%', flexDirection: 'row', flexWrap: 'wrap', gap: 9 },
  genderOption: { flexGrow: 1, flexBasis: '46%', minHeight: 48, borderWidth: 1, borderRadius: 12, paddingHorizontal: 12, alignItems: 'center', justifyContent: 'center' },
  profileAvatar: { width: 68, height: 68, borderRadius: 24, alignItems: 'center', justifyContent: 'center' },
  profileName: { fontFamily: 'serif', fontSize: 22, fontWeight: '400', marginTop: 14, marginBottom: 5 },
  infoRow: { minHeight: 48, borderBottomWidth: StyleSheet.hairlineWidth, flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between' },
  suggestionButton: { alignSelf: 'flex-start', minHeight: 42, borderWidth: 1, borderRadius: 12, paddingHorizontal: 14, justifyContent: 'center', marginTop: 14 },
  weekRecapPanel: { marginTop: 14 },
  weekRecapTitle: { fontFamily: 'serif', fontSize: 20, marginTop: 10, marginBottom: 7 },
  reminderPanel: { borderRadius: 16, borderWidth: StyleSheet.hairlineWidth, padding: 16, marginTop: 12 },
  reminderHeader: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between' },
  reminderTimeRow: { flexDirection: 'row', alignItems: 'center', justifyContent: 'flex-end', gap: 10, marginTop: 14 },
  reminderTimeInput: { width: 48, height: 42, borderWidth: 1, borderRadius: 10, textAlign: 'center', fontSize: 16, fontWeight: '700' },
  reminderSaveButton: { minHeight: 42, borderRadius: 10, alignItems: 'center', justifyContent: 'center', paddingHorizontal: 13, marginLeft: 4 },
  preferenceRow: { height: 50, borderBottomWidth: StyleSheet.hairlineWidth, flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between' },
  signOutButton: { minHeight: 48, borderWidth: 1, borderRadius: 9, alignItems: 'center', justifyContent: 'center', marginTop: 28 },
  statusBox: { alignItems: 'center', justifyContent: 'center', padding: 26 },
  emptyState: { width: '100%', paddingVertical: 18 },
  boot: { flex: 1, justifyContent: 'center', alignItems: 'center' },
  onboardingWrap: { flexGrow: 1, justifyContent: 'center', paddingHorizontal: 22 },
  onboardingCard: { width: '100%', maxWidth: 520, alignSelf: 'center', borderRadius: 24, borderWidth: 1, padding: 22, alignItems: 'center', shadowColor: '#18322A', shadowOpacity: 0.08, shadowRadius: 18, shadowOffset: { width: 0, height: 8 }, elevation: 4 },
  onboardingIcon: { width: 58, height: 58, borderRadius: 15 },
  onboardingTitle: { fontFamily: 'serif', fontSize: 28, fontWeight: '400', marginTop: 15, textAlign: 'center' },
  onboardingCopy: { maxWidth: 390, fontSize: 15, lineHeight: 22, textAlign: 'center', marginTop: 7, marginBottom: 10 },
  fieldRow: { flexDirection: 'row', alignItems: 'flex-start', gap: 12, width: '100%' },
  goalPreview: { width: '100%', borderRadius: 16, padding: 15, marginTop: 20 },
  onboardingButton: { width: '100%', alignSelf: 'stretch', minHeight: 58, paddingHorizontal: 18 },
  onboardingButtonText: { width: '100%', textAlign: 'center' },
  profileActions: { flexDirection: 'row', justifyContent: 'flex-end', alignItems: 'center', gap: 12, marginTop: 16 },
  cancelButton: { minHeight: 48, minWidth: 88, borderWidth: 1, borderRadius: 12, alignItems: 'center', justifyContent: 'center', paddingHorizontal: 16 },
  saveProfileButton: { minHeight: 48, minWidth: 132, borderRadius: 12, alignItems: 'center', justifyContent: 'center', paddingHorizontal: 16 },
});
