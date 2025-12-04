import streamlit as st
import pandas as pd
import numpy as np
import json
import time
import os
import matplotlib.pyplot as plt
from scipy.fft import fft, fftfreq
from scipy.signal import butter, filtfilt, find_peaks
from scipy.interpolate import interp1d
from streamlit_option_menu import option_menu

# ==============================================================================
# CONFIGURAÇÕES
# ==============================================================================
DATA_FILE = "live_data.json"
STATUS_FILE = "status.json"
DB_FOLDER = "database_pacientes"

st.set_page_config(page_title="HomeFisio Pro", layout="wide", page_icon="🏥")
# Estilo científico para os gráficos Matplotlib
plt.style.use('seaborn-v0_8-whitegrid')

COLOR_PRIMARY = "#006A6A"
COLOR_SECONDARY = "#2ecc71"

# ==============================================================================
# MÓDULO: CÁLCULO NUMÉRICO E SINAIS (BASE)
# ==============================================================================
def calculate_jerk(y_values, t_values):
    try:
        y = pd.Series(y_values); t = pd.Series(t_values)
        dt = t.diff().fillna(0.02).replace(0, 0.02)
        velocity = y.diff() / dt
        acc = velocity.diff() / dt
        jerk = acc.diff() / dt
        rms_jerk = np.sqrt((jerk ** 2).mean())
        return 0.0 if np.isnan(rms_jerk) else rms_jerk
    except: return 0.0

def interpret_results(amplitude, jerk_score, forca_kg, torque_max, energia_j, freq_pico):
    laudo = []
    if amplitude < 15: laudo.append(f"⚠️ **Amplitude Crítica ({amplitude:.1f}°):** Movimento curto.")
    elif amplitude < 60: laudo.append(f"ℹ️ **Amplitude Funcional ({amplitude:.1f}°):** Aceitável.")
    else: laudo.append(f"✅ **Amplitude Excelente ({amplitude:.1f}°):** Ótima excursão.")
    
    if freq_pico > 4.0: laudo.append(f"🚨 **Tremor ({freq_pico:.1f} Hz):** Oscilação rápida detectada.")
    elif jerk_score > 800: laudo.append(f"⚠️ **Instabilidade:** Movimento brusco (Jerk {jerk_score:.0f}).")
    else: laudo.append(f"✨ **Controle:** Fluido.")
        
    laudo.append(f"💪 **Força:** {forca_kg:.1f} kgf ({torque_max:.1f} Nm).")
    if energia_j > 100: laudo.append(f"🔥 **Alta Demanda:** {energia_j:.1f} J.")
    
    return "\n\n".join(laudo)

def derivacao_numerica_central(y, h):
    dy = np.zeros_like(y)
    if len(y) < 3: return dy
    dy[1:-1] = (y[2:] - y[:-2]) / (2 * h)
    dy[0], dy[-1] = (y[1] - y[0]) / h, (y[-1] - y[-2]) / h
    return dy

def integracao_simpson(y, h):
    if len(y) < 3: return np.sum(y) * h 
    soma = y[0] + y[-1] + 4*np.sum(y[1:-1:2]) + 2*np.sum(y[2:-1:2])
    return (h / 3) * soma

def filtro_convolucao(sinal, janela=10):
    if len(sinal) < janela: return sinal
    h = np.ones(janela) / janela
    return np.convolve(sinal, h, mode='same')

def analise_fft(sinal, fs):
    N = len(sinal)
    if N == 0: return None, None
    sinal_ac = sinal - np.mean(sinal)
    yf = fft(sinal_ac.values) if hasattr(sinal_ac, 'values') else fft(sinal_ac)
    xf = fftfreq(N, 1/fs)[:N//2]
    amplitude = 2.0/N * np.abs(yf[0:N//2])
    return xf, amplitude

# ==============================================================================
# MÓDULO NOVO: RELATÓRIO CIENTÍFICO (OCTAVE STYLE)
# ==============================================================================
def gerar_relatorio_octave(t_in, y_in, titulo):
    """
    Replica a análise avançada do seu script Octave:
    1. Filtro Butterworth 4ª ordem (Sinais)
    2. Ensemble Averaging (Consistência de Ciclos)
    3. Retrato de Fase (Coordenação)
    4. FFT com Zona de Tremor
    """
    
    # 1. Preparação (Similar ao Octave)
    t = np.array(t_in); t = t - t[0]
    dt = np.mean(np.diff(t))
    fs = 1/dt if dt > 0 else 50
    y_raw = np.array(y_in)

    # 2. Filtro Butterworth (Igual ao Octave 'butter')
    nyq = 0.5 * fs
    b, a = butter(4, 6/nyq, btype='low') # 6Hz cutoff
    y_filt = filtfilt(b, a, y_raw)
    
    # Velocidade (Gradiente)
    v = np.gradient(y_filt, dt)

    # 3. Segmentação de Ciclos (FindPeaks)
    data_range = np.max(y_filt) - np.min(y_filt)
    peaks, _ = find_peaks(y_filt, prominence=data_range*0.25, distance=int(fs*0.8))
    
    # 4. Ensemble (Normalização 0-100%)
    cycles_norm = []
    if len(peaks) > 1:
        x_norm = np.linspace(0, 100, 100)
        for i in range(len(peaks)-1):
            start, end = peaks[i], peaks[i+1]
            cycle = y_filt[start:end]
            if len(cycle) > 10:
                f_interp = interp1d(np.linspace(0, 100, len(cycle)), cycle, kind='cubic')
                cycles_norm.append(f_interp(x_norm))

    # 5. FFT
    L = len(y_filt)
    Y_fft = fft(y_filt - np.mean(y_filt))
    P1 = 2.0/L * np.abs(Y_fft[:L//2])
    freqs = fftfreq(L, dt)[:L//2]

    # --- PLOTAGEM CIENTÍFICA (MATPLOTLIB) ---
    fig = plt.figure(figsize=(12, 8))
    gs = fig.add_gridspec(2, 2)
    
    # G1: Ensemble (Consistência)
    ax1 = fig.add_subplot(gs[0, :]) # Ocupa topo
    if cycles_norm:
        mean_c = np.mean(cycles_norm, axis=0)
        std_c = np.std(cycles_norm, axis=0)
        for c in cycles_norm: ax1.plot(np.linspace(0,100,100), c, color='gray', alpha=0.1)
        ax1.plot(np.linspace(0,100,100), mean_c, color=COLOR_PRIMARY, linewidth=2, label='Média')
        ax1.fill_between(np.linspace(0,100,100), mean_c-std_c, mean_c+std_c, color=COLOR_PRIMARY, alpha=0.2)
        ax1.text(50, np.max(mean_c), f"ROM Médio: {np.ptp(mean_c):.1f}°", ha='center', fontweight='bold')
    else:
        ax1.plot(t, y_filt, color=COLOR_PRIMARY)
        ax1.text(np.mean(t), np.mean(y_filt), "Ciclos não detectados (Série Contínua)", ha='center')
    ax1.set_title(f"1. Padrão Motor e Consistência - {titulo}", fontweight='bold')
    ax1.set_xlabel("% do Ciclo"); ax1.set_ylabel("Ângulo (°)")

    # G2: Retrato de Fase
    ax2 = fig.add_subplot(gs[1, 0])
    sc = ax2.scatter(y_filt, v, c=t, cmap='viridis', s=5, alpha=0.5)
    ax2.set_title("2. Coordenação (Retrato de Fase)", fontweight='bold')
    ax2.set_xlabel("Posição (°)"); ax2.set_ylabel("Velocidade (°/s)")
    plt.colorbar(sc, ax=ax2, label="Tempo")

    # G3: FFT
    ax3 = fig.add_subplot(gs[1, 1])
    ax3.plot(freqs, P1, 'k', linewidth=1)
    ax3.set_xlim(0, 10)
    # Zona de tremor (4-8Hz) - Igual ao Octave
    yl = ax3.get_ylim()
    ax3.fill_between([4, 8], 0, yl[1], color='red', alpha=0.1, label='Tremor')
    ax3.set_title("3. Fluidez (FFT)", fontweight='bold')
    ax3.set_xlabel("Hz"); ax3.set_ylabel("Mag")
    
    plt.tight_layout()
    return fig

# ==============================================================================
# MOTOR BIOMECÂNICO
# ==============================================================================
def processar_biomecanica(df, exercise_name, peso, altura, genero):
    try:
        g = 9.81
        coefs = {"Masculino": {"coxa": 0.105, "perna": 0.0475, "pe": 0.0143},
                 "Feminino":  {"coxa": 0.1175, "perna": 0.0483, "pe": 0.0129}}
        lens = {"perna": 0.246, "pe": 0.152}
        c = coefs.get(genero, coefs["Masculino"])
        
        l_alavanca = 0.4
        if "Joelho" in exercise_name:
            m_seg = peso * (c["perna"] + c["pe"])
            l_tibia = altura * lens["perna"]
            l_alavanca = l_tibia + (altura * lens["pe"] * 0.5)
            r_com = l_tibia * 0.606 
            if 'Angulo_Joelho' in df.columns: raw_angle = df['Angulo_Joelho']
            elif 'p2' in df.columns and 'p1' in df.columns: raw_angle = df['p2'] - df['p1']
            else: raw_angle = df.iloc[:, 0]
        elif "Quadril" in exercise_name:
            m_seg = peso * (c["coxa"] + c["perna"] + c["pe"])
            l_alavanca = altura * 0.53 
            r_com = l_alavanca * 0.45 
            raw_angle = df['r1'] if 'r1' in df.columns else df.iloc[:, 0]
        else:
            m_seg = peso * c["pe"]
            l_alavanca = altura * lens["pe"]
            r_com = l_alavanca * 0.5
            raw_angle = df['p3'] - df['p2'] if 'p3' in df.columns else df.iloc[:, 0]

        fs = 50.0; dt = 1.0/fs
        t_orig = df['tempo_s'] if 'tempo_s' in df.columns else (df['t'] if 't' in df.columns else np.arange(len(df))*dt)
        t_novo = np.arange(t_orig.min(), t_orig.max(), dt)
        
        ang_interp = np.interp(t_novo, t_orig, raw_angle)
        ang_filt = filtro_convolucao(ang_interp, 10)
        
        theta_rad = np.radians(ang_filt)
        omega = derivacao_numerica_central(theta_rad, dt)
        alpha = derivacao_numerica_central(omega, dt)
        
        I_seg = m_seg * (r_com ** 2)
        torque = (I_seg * alpha) + (m_seg * g * r_com * np.sin(theta_rad))
        forca = torque / l_alavanca
        energy = integracao_simpson(np.abs(torque * omega), dt)
        
        return t_novo, ang_filt, torque, forca, energy, m_seg
    except: return [], [], [], [], 0, 0

# ==============================================================================
# DASHBOARD INTERATIVO
# ==============================================================================
def renderizar_dashboard(t_reg, ang, torque, forca_n, energia, m_seg):
    if len(t_reg) == 0: return

    amp = np.max(ang) - np.min(ang)
    jerk = calculate_jerk(ang, t_reg)
    f_kg = np.max(np.abs(forca_n)) / 9.81
    
    xf, yf = analise_fft(ang, 50)
    freq_pic = xf[np.argmax(yf[1:]) + 1] if xf is not None and len(xf)>1 else 0

    k1, k2, k3, k4, k5 = st.columns(5)
    k1.metric("Amplitude", f"{amp:.1f}°")
    k2.metric("Fluidez", f"{jerk:.0f}")
    k3.metric("Carga Máx", f"{f_kg:.1f} kgf", delta="Prático")
    k4.metric("Torque", f"{np.max(np.abs(torque)):.1f} Nm")
    k5.metric("Energia", f"{energia:.1f} J")
    
    st.info(interpret_results(amp, jerk, f_kg, np.max(np.abs(torque)), energia, freq_pic))
    
    tab1, tab2, tab3 = st.tabs(["📊 Biomecânica", "🌊 Espectro", "📉 Cinemática"])
    with tab1:
        df_bio = pd.DataFrame({"Força Linear (N)": forca_n, "Torque Articular (Nm)": torque}, index=t_reg)
        df_bio.index.name = "Tempo (s)" 
        st.line_chart(df_bio, color=[COLOR_PRIMARY, COLOR_SECONDARY])
    with tab2:
        if xf is not None:
            df_fft = pd.DataFrame({"Amplitude Espectral": yf}, index=xf)
            df_fft.index.name = "Frequência (Hz)"
            st.bar_chart(df_fft.loc[:12], color=COLOR_SECONDARY)
    with tab3:
        df_cine = pd.DataFrame({"Ângulo (graus)": ang}, index=t_reg)
        df_cine.index.name = "Tempo (s)"
        st.line_chart(df_cine, color=COLOR_PRIMARY)

# ==============================================================================
# UI PRINCIPAL
# ==============================================================================
with st.sidebar:
    st.markdown(f"<h2 style='color: {COLOR_PRIMARY};'>HOME-FISIO Pro</h2>", unsafe_allow_html=True)
    selected_mode = option_menu(None, ["Monitoramento", "Histórico"], icons=["activity", "folder"], default_index=0,
        styles={"nav-link-selected": {"background-color": COLOR_SECONDARY}})
    
    st.divider()
    st.caption("Paciente")
    gen_in = st.radio("Gênero", ["Masculino", "Feminino"], horizontal=True)
    pes_in = st.number_input("Peso (kg)", 10.0, 200.0, 70.0)
    alt_in = st.number_input("Altura (m)", 0.5, 2.5, 1.70)
    
    if selected_mode == "Monitoramento":
        ex_in = st.selectbox("Exercício", ["Flexão de Joelho", "Abdução de Quadril", "Dorsiflexão"])

if 'dados' not in st.session_state: st.session_state.dados = pd.DataFrame()
if 'coletando' not in st.session_state: st.session_state.coletando = False
if 't_start' not in st.session_state: st.session_state.t_start = None
if 'last_read_t' not in st.session_state: st.session_state.last_read_t = 0

# ==============================================================================
# 1. MONITORAMENTO
# ==============================================================================
if selected_mode == "Monitoramento":
    st.title(f"📡 Monitor: {ex_in}")
    live_msg = st.empty()
    live_chart = st.empty()
    
    try:
        if os.path.exists(STATUS_FILE):
            with open(STATUS_FILE, 'r') as f:
                st_json = json.load(f)
                if st_json.get("collecting") and not st.session_state.coletando:
                    st.session_state.coletando = True
                    st.session_state.dados = pd.DataFrame()
                    st.session_state.t_start = None; st.session_state.last_read_t = 0
                    st.rerun()
                elif not st_json.get("collecting") and st.session_state.coletando:
                    st.session_state.coletando = False
                    st.rerun()
    except: pass

    if st.session_state.coletando:
        with live_msg.container(): st.toast("Gravando...", icon="🟢")
        df_init = pd.DataFrame(columns=["Ângulo Tempo Real (°)"])
        chart = live_chart.line_chart(df_init, color=COLOR_PRIMARY)
        
        while True:
            try:
                if os.path.exists(STATUS_FILE):
                    with open(STATUS_FILE, 'r') as f:
                        if not json.load(f).get("collecting"): break
                if os.path.exists(DATA_FILE):
                    with open(DATA_FILE, 'r') as f: content = f.read().strip()
                    if content:
                        d = json.loads(content)
                        if d.get('t') is not None and d.get('t') != st.session_state.last_read_t:
                            st.session_state.last_read_t = d['t']
                            if st.session_state.t_start is None: st.session_state.t_start = d['t']
                            t_sec = (d['t'] - st.session_state.t_start)/1000.0
                            
                            if "Joelho" in ex_in: val = d['sensor2']['pitch'] - d['sensor1']['pitch']
                            elif "Quadril" in ex_in: val = d['sensor1']['roll']
                            else: val = d['sensor3']['pitch'] - d['sensor2']['pitch']
                            
                            new_row = {'t': t_sec, 'val': val, 'p1': d['sensor1']['pitch'], 'p2': d['sensor2']['pitch'], 'p3': d['sensor3']['pitch'], 'r1': d['sensor1']['roll']}
                            st.session_state.dados = pd.concat([st.session_state.dados, pd.DataFrame([new_row])], ignore_index=True)
                            chart.add_rows(pd.DataFrame({"Ângulo Tempo Real (°)": [val]}, index=[t_sec]))
            except: pass
            time.sleep(0.05)
        st.rerun()

    elif not st.session_state.dados.empty:
        st.success("✅ Coleta Finalizada.")
        df_proc = st.session_state.dados.copy()
        if "Joelho" in ex_in: df_proc['Angulo_Joelho'] = df_proc['val']
        elif "Quadril" in ex_in: df_proc['r1'] = df_proc['val']
        else: df_proc['Angulo_Tornozelo'] = df_proc['val']

        t, ang, tor, forc, ener, m = processar_biomecanica(df_proc, ex_in, pes_in, alt_in, gen_in)
        renderizar_dashboard(t, ang, tor, forc, ener, m)
        if st.button("🗑️ Descartar"):
            st.session_state.dados = pd.DataFrame(); st.rerun()
    else:
        st.markdown("<div style='text-align: center; color: gray; padding: 50px;'>Aguardando início pelo App...</div>", unsafe_allow_html=True)

# ==============================================================================
# 2. HISTÓRICO (COM RELATÓRIO CIENTÍFICO OCTAVE-STYLE)
# ==============================================================================
if selected_mode == "Histórico":
    st.title("📂 Histórico")
    if not os.path.exists(DB_FOLDER): os.makedirs(DB_FOLDER)
    pacientes = [d for d in os.listdir(DB_FOLDER) if os.path.isdir(os.path.join(DB_FOLDER, d))]
    paciente_sel = st.selectbox("Paciente", pacientes) if pacientes else None
    
    if paciente_sel:
        path = os.path.join(DB_FOLDER, paciente_sel)
        arquivos = [f for f in os.listdir(path) if f.endswith('.csv')]
        arquivos.sort(reverse=True)
        
        for arq in arquivos:
            with st.expander(f"📄 {arq}"):
                c1, c2, c3 = st.columns([3, 3, 1])
                with c1: ver = st.button(f"Abrir Painel", key=f"v_{arq}")
                # NOVO BOTÃO PARA RELATÓRIO CIENTÍFICO
                with c2: rel = st.button(f"🔬 Relatório Científico", key=f"r_{arq}")
                with c3: 
                    if st.button("🗑️", key=f"d_{arq}"):
                        os.remove(os.path.join(path, arq))
                        try: os.remove(os.path.join(path, arq.replace(".csv", ".json")))
                        except: pass
                        st.rerun()

                df = pd.read_csv(os.path.join(path, arq))
                json_p = os.path.join(path, arq.replace(".csv", ".json"))
                w, h, g, ex = pes_in, alt_in, gen_in, "Geral"
                if os.path.exists(json_p):
                    with open(json_p, 'r') as f: meta = json.load(f)
                    w, h, g, ex = meta.get('weight', w), meta.get('height', h), meta.get('gender', g), meta.get('exercise', ex)

                if ver:
                    t, ang, tor, forc, ener, m = processar_biomecanica(df, ex, w, h, g)
                    renderizar_dashboard(t, ang, tor, forc, ener, m)
                    st.download_button("📥 Baixar CSV", df.to_csv().encode('utf-8'), arq, "text/csv")

                if rel:
                    st.markdown("---")
                    st.subheader("🔬 Relatório Biomecânico (Padrão Pesquisa)")
                    st.caption("Pipeline: Filtro Butterworth 4ª Ordem -> Segmentação -> Ensemble Averaging")
                    
                    # Usa o processamento básico para pegar os dados crus alinhados
                    t_raw, ang_raw, _, _, _, _ = processar_biomecanica(df, ex, w, h, g)
                    
                    # GERA O RELATÓRIO CIENTÍFICO COMPLEXO
                    fig = gerar_relatorio_octave(t_raw, ang_raw, ex)
                    st.pyplot(fig)