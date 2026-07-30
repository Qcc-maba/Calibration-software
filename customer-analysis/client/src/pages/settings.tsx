import { useState, useEffect } from "react";
import { motion } from "framer-motion";
import DashboardLayout from "@/components/layout/DashboardLayout";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Switch } from "@/components/ui/switch";
import { Separator } from "@/components/ui/separator";
import { Slider } from "@/components/ui/slider";
import { useToast } from "@/hooks/use-toast";
import { 
  Settings as SettingsIcon, 
  Database,
  Bell,
  Palette,
  Shield,
  RefreshCw,
  Star,
  Save
} from "lucide-react";

const defaultConfig = {
  weights: { tenure: 25, revenue: 40, frequency: 35 },
  thresholds: { A: 85, B: 70, C: 55, D: 40 },
  maxValues: { tenureMonths: 60, revenueAmount: 500000 }
};

export default function SettingsPage() {
  const { toast } = useToast();
  const [config, setConfig] = useState(defaultConfig);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  
  useEffect(() => {
    fetch('/api/settings/scoring')
      .then(res => res.json())
      .then(data => {
        setConfig(data);
        setLoading(false);
      })
      .catch(() => setLoading(false));
  }, []);
  
  const handleSave = async () => {
    setSaving(true);
    try {
      const res = await fetch('/api/settings/scoring', {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(config)
      });
      const data = await res.json();
      if (res.ok) {
        toast({ title: 'נשמר בהצלחה', description: 'הגדרות הציון עודכנו. הרץ סנכרון מחדש כדי לעדכן ציוני לקוחות.' });
      } else {
        toast({ title: 'שגיאה', description: data.error, variant: 'destructive' });
      }
    } catch (error) {
      toast({ title: 'שגיאה', description: 'לא ניתן לשמור את ההגדרות', variant: 'destructive' });
    }
    setSaving(false);
  };
  
  const updateWeight = (key: 'tenure' | 'revenue' | 'frequency', value: number) => {
    const others = Object.entries(config.weights).filter(([k]) => k !== key);
    const remaining = 100 - value;
    const otherSum = others.reduce((sum, [, v]) => sum + v, 0);
    
    if (otherSum === 0) return;
    
    const newWeights = { ...config.weights, [key]: value };
    others.forEach(([k, v]) => {
      newWeights[k as keyof typeof config.weights] = Math.round((v / otherSum) * remaining);
    });
    
    const total = Object.values(newWeights).reduce((a, b) => a + b, 0);
    if (total !== 100) {
      const diff = 100 - total;
      const firstOther = others[0][0] as keyof typeof config.weights;
      newWeights[firstOther] += diff;
    }
    
    setConfig({ ...config, weights: newWeights });
  };

  return (
    <DashboardLayout>
      <motion.div 
        className="space-y-6 max-w-4xl mx-auto text-right"
        dir="rtl"
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
      >
        <div>
          <h1 className="text-3xl font-bold">הגדרות</h1>
          <p className="text-muted-foreground">ניהול הגדרות המערכת</p>
        </div>

        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <Database className="w-5 h-5" />
              חיבור לבסיס נתונים
            </CardTitle>
            <CardDescription>הגדרות סנכרון נתונים מ-SQL Server</CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div className="space-y-2">
                <Label>כתובת שרת</Label>
                <Input value="51.17.121.203\QCC,1433" disabled className="font-mono text-sm" />
              </div>
              <div className="space-y-2">
                <Label>בסיס נתונים</Label>
                <Input value="QCCData" disabled className="font-mono text-sm" />
              </div>
            </div>
            <div className="flex items-center justify-between p-4 bg-muted/50 rounded-lg">
              <div>
                <p className="font-medium">סנכרון אוטומטי</p>
                <p className="text-sm text-muted-foreground">הרץ את סקריפט הסנכרון מהמחשב המקומי</p>
              </div>
              <Button variant="outline" className="gap-2" data-testid="button-sync">
                <RefreshCw className="w-4 h-4" />
                סנכרן עכשיו
              </Button>
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <Star className="w-5 h-5" />
              חישוב ציון לקוח
            </CardTitle>
            <CardDescription>הגדרת משקולות וספים לדירוג לקוחות (A-E)</CardDescription>
          </CardHeader>
          <CardContent className="space-y-6">
            <div>
              <h4 className="font-medium mb-4">משקולות (סה"כ 100%)</h4>
              <div className="space-y-4">
                <div className="space-y-2">
                  <div className="flex justify-between">
                    <span className="text-sm text-muted-foreground">ותק (חודשים מהרכישה הראשונה)</span>
                    <span className="font-mono font-bold">{config.weights.tenure}%</span>
                  </div>
                  <Slider
                    value={[config.weights.tenure]}
                    onValueChange={([v]) => updateWeight('tenure', v)}
                    max={100}
                    step={5}
                    className="w-full"
                    data-testid="slider-tenure-weight"
                  />
                </div>
                <div className="space-y-2">
                  <div className="flex justify-between">
                    <span className="text-sm text-muted-foreground">סכום רכישות (24 חודשים אחרונים)</span>
                    <span className="font-mono font-bold">{config.weights.revenue}%</span>
                  </div>
                  <Slider
                    value={[config.weights.revenue]}
                    onValueChange={([v]) => updateWeight('revenue', v)}
                    max={100}
                    step={5}
                    className="w-full"
                    data-testid="slider-revenue-weight"
                  />
                </div>
                <div className="space-y-2">
                  <div className="flex justify-between">
                    <span className="text-sm text-muted-foreground">תדירות רכישות</span>
                    <span className="font-mono font-bold">{config.weights.frequency}%</span>
                  </div>
                  <Slider
                    value={[config.weights.frequency]}
                    onValueChange={([v]) => updateWeight('frequency', v)}
                    max={100}
                    step={5}
                    className="w-full"
                    data-testid="slider-frequency-weight"
                  />
                </div>
              </div>
            </div>
            
            <Separator />
            
            <div>
              <h4 className="font-medium mb-4">ספי דירוג</h4>
              <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
                <div className="space-y-2">
                  <Label className="flex items-center gap-2">
                    <span className="w-6 h-6 rounded-full bg-emerald-500 text-white text-xs flex items-center justify-center font-bold">A</span>
                    מעל
                  </Label>
                  <Input
                    type="number"
                    value={config.thresholds.A}
                    onChange={e => setConfig({ ...config, thresholds: { ...config.thresholds, A: Number(e.target.value) }})}
                    className="font-mono"
                    data-testid="input-threshold-a"
                  />
                </div>
                <div className="space-y-2">
                  <Label className="flex items-center gap-2">
                    <span className="w-6 h-6 rounded-full bg-blue-500 text-white text-xs flex items-center justify-center font-bold">B</span>
                    מעל
                  </Label>
                  <Input
                    type="number"
                    value={config.thresholds.B}
                    onChange={e => setConfig({ ...config, thresholds: { ...config.thresholds, B: Number(e.target.value) }})}
                    className="font-mono"
                    data-testid="input-threshold-b"
                  />
                </div>
                <div className="space-y-2">
                  <Label className="flex items-center gap-2">
                    <span className="w-6 h-6 rounded-full bg-amber-500 text-white text-xs flex items-center justify-center font-bold">C</span>
                    מעל
                  </Label>
                  <Input
                    type="number"
                    value={config.thresholds.C}
                    onChange={e => setConfig({ ...config, thresholds: { ...config.thresholds, C: Number(e.target.value) }})}
                    className="font-mono"
                    data-testid="input-threshold-c"
                  />
                </div>
                <div className="space-y-2">
                  <Label className="flex items-center gap-2">
                    <span className="w-6 h-6 rounded-full bg-orange-500 text-white text-xs flex items-center justify-center font-bold">D</span>
                    מעל
                  </Label>
                  <Input
                    type="number"
                    value={config.thresholds.D}
                    onChange={e => setConfig({ ...config, thresholds: { ...config.thresholds, D: Number(e.target.value) }})}
                    className="font-mono"
                    data-testid="input-threshold-d"
                  />
                </div>
              </div>
              <p className="text-xs text-muted-foreground mt-2">E = מתחת לסף D</p>
            </div>
            
            <Separator />
            
            <div>
              <h4 className="font-medium mb-4">ערכי מקסימום לחישוב</h4>
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                <div className="space-y-2">
                  <Label>חודשי ותק מקסימליים</Label>
                  <Input
                    type="number"
                    value={config.maxValues.tenureMonths}
                    onChange={e => setConfig({ ...config, maxValues: { ...config.maxValues, tenureMonths: Number(e.target.value) }})}
                    className="font-mono"
                    data-testid="input-max-tenure"
                  />
                  <p className="text-xs text-muted-foreground">{config.maxValues.tenureMonths} חודשים = ציון 100</p>
                </div>
                <div className="space-y-2">
                  <Label>סכום הכנסות מקסימלי (₪)</Label>
                  <Input
                    type="number"
                    value={config.maxValues.revenueAmount}
                    onChange={e => setConfig({ ...config, maxValues: { ...config.maxValues, revenueAmount: Number(e.target.value) }})}
                    className="font-mono"
                    data-testid="input-max-revenue"
                  />
                  <p className="text-xs text-muted-foreground">₪{config.maxValues.revenueAmount.toLocaleString()} = ציון 100</p>
                </div>
              </div>
            </div>
            
            <div className="flex justify-end pt-4">
              <Button onClick={handleSave} disabled={saving} className="gap-2" data-testid="button-save-scoring">
                <Save className="w-4 h-4" />
                {saving ? 'שומר...' : 'שמור הגדרות'}
              </Button>
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <Bell className="w-5 h-5" />
              התראות
            </CardTitle>
            <CardDescription>הגדרות התראות והודעות</CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="flex items-center gap-4">
              <Switch defaultChecked data-testid="switch-overdue-alerts" className="flex-shrink-0" dir="ltr" />
              <div className="flex-1">
                <p className="font-medium">התראות כיול באיחור</p>
                <p className="text-sm text-muted-foreground">קבל התראה כאשר מכשיר מאחר בכיול</p>
              </div>
            </div>
            <Separator />
            <div className="flex items-center gap-4">
              <Switch defaultChecked data-testid="switch-reminder-alerts" className="flex-shrink-0" dir="ltr" />
              <div className="flex-1">
                <p className="font-medium">תזכורות כיול קרוב</p>
                <p className="text-sm text-muted-foreground">קבל תזכורת שבוע לפני תאריך כיול</p>
              </div>
            </div>
            <Separator />
            <div className="flex items-center gap-4">
              <Switch data-testid="switch-email-alerts" className="flex-shrink-0" dir="ltr" />
              <div className="flex-1">
                <p className="font-medium">התראות מייל</p>
                <p className="text-sm text-muted-foreground">שלח התראות גם לכתובת מייל</p>
              </div>
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <Palette className="w-5 h-5" />
              תצוגה
            </CardTitle>
            <CardDescription>התאמה אישית של הממשק</CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="flex items-center gap-4">
              <Switch data-testid="switch-dark-mode" className="flex-shrink-0" dir="ltr" />
              <div className="flex-1">
                <p className="font-medium">מצב כהה</p>
                <p className="text-sm text-muted-foreground">החלף לתצוגה כהה</p>
              </div>
            </div>
            <Separator />
            <div className="flex items-center gap-4">
              <Switch defaultChecked data-testid="switch-animations" className="flex-shrink-0" dir="ltr" />
              <div className="flex-1">
                <p className="font-medium">הצג אנימציות</p>
                <p className="text-sm text-muted-foreground">אפקטים חזותיים בממשק</p>
              </div>
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <Shield className="w-5 h-5" />
              אבטחה
            </CardTitle>
            <CardDescription>הגדרות אבטחה וגישה</CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="flex items-center gap-4">
              <Switch data-testid="switch-2fa" className="flex-shrink-0" dir="ltr" />
              <div className="flex-1">
                <p className="font-medium">אימות דו-שלבי</p>
                <p className="text-sm text-muted-foreground">הוסף שכבת אבטחה נוספת</p>
              </div>
            </div>
            <Separator />
            <div className="space-y-2">
              <Label>שינוי סיסמה</Label>
              <div className="flex gap-2">
                <Input type="password" placeholder="סיסמה נוכחית" className="flex-1" />
                <Input type="password" placeholder="סיסמה חדשה" className="flex-1" />
                <Button variant="outline" data-testid="button-change-password">עדכן</Button>
              </div>
            </div>
          </CardContent>
        </Card>
      </motion.div>
    </DashboardLayout>
  );
}
