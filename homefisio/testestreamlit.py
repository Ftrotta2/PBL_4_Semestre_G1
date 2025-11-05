import streamlit as st
import pandas as pd
import numpy as np
import snowflake.connector
import streamlit_option_menu
from streamlit_option_menu import option_menu
from io import StringIO


# Menu lateral
with st.sidebar:
    selected = option_menu(
        menu_title="Menu Principal",  # Título do menu
        options=["Home", "Paciente", "Minha Conta", "Contato"],  # Opções do menu
        icons=["house", "heart-pulse", "person", "envelope"],  # Ícones do menu
        default_index=0,
        styles={
            "container": {"padding": "5px", "background-color": "#f8f9fa"},  # Ajuste do container
            "icon": {"font-size": "20px", "color": "black", "vertical-align": "middle"},  # Ícones com alinhamento vertical
            "nav-link": {
                "font-size": "16px",  # Ajuste do tamanho da fonte
                "text-align": "left",  # Alinhamento do texto à esquerda
                "margin": "5px",  # Margem para espaçamento
                "color": "black",  # Cor do texto
                "display": "flex",  # Usando flexbox para alinhar ícones e texto na mesma linha
                "align-items": "center",  # Alinha o texto e ícone no centro verticalmente
            },
            "nav-link-selected": {
                "background-color": "#f1f1f1",  # Cor do item selecionado
                "color": "black",  # Cor do texto do item selecionado
            },
        }
    )
if selected == "Home":
    st.header('Acompanhamento em Tempo Real')

    # Seção de seleção de dispositivo (fictício)
    dispositivos = ["Dispositivo 1", "Dispositivo 2", "Dispositivo 3"]  # Dispositivos fictícios
    dispositivo_selecionado = st.selectbox("Selecione o dispositivo para acompanhar:", dispositivos)

    st.write(f"**Dispositivo selecionado**: {dispositivo_selecionado}")

    # Simulando dados de dispositivos e gráficos (substituir por dados reais quando disponível)
    st.subheader("Gráficos em Tempo Real")

    # Gerar alguns dados fictícios (por enquanto)
    dados_temp = pd.DataFrame(np.random.randn(20, 3), columns=["Acelerômetro X", "Acelerômetro Y", "Acelerômetro Z"])

    # Exibir gráficos fictícios
    st.line_chart(dados_temp)

    # Botão para simular atualização de dados
    if st.button("Atualizar Dados em Tempo Real"):
        st.success("Dados atualizados com sucesso! Mostrando novos gráficos.")
        dados_temp = pd.DataFrame(np.random.randn(20, 3), columns=["Acelerômetro X", "Acelerômetro Y", "Acelerômetro Z"])
        st.line_chart(dados_temp)

    # Link fictício para relatórios (substituir com link real quando disponível)
    st.write("### Relatório")
    st.markdown("[Ver Relatório Detalhado](#)")  # Substitua o # pelo link real do relatório
        
if selected == "Paciente":
    # Lista de pacientes fictícios (alterar conforme necessário)
    pacientes = [
        {"nome": "João Silva", "id": 1, "idade": "75", "DataAVC": "xx/xx/xxxx"},
        {"nome": "João Oliveira", "id": 1, "idade": "75", "DataAVC": "xx/xx/xxxx"},
        {"nome": "João Azevedo", "id": 1, "idade": "75", "DataAVC": "xx/xx/xxxx"}    ]

    # Simulando sessões de pacientes (substituir por dados reais ou CSV posteriormente)
    sessions_data = {
        1: [
            {"data": "2025-11-01", "dados": pd.DataFrame(np.random.randn(5, 3), columns=["a", "b", "c"])},
            {"data": "2025-11-05", "dados": pd.DataFrame(np.random.randn(5, 3), columns=["a", "b", "c"])}
        ],
        2: [
            {"data": "2025-11-02", "dados": pd.DataFrame(np.random.randn(5, 3), columns=["a", "b", "c"])},
        ],
        3: [
            {"data": "2025-11-03", "dados": pd.DataFrame(np.random.randn(5, 3), columns=["a", "b", "c"])}
        ]
    }

    # Exibição da lista de pacientes
    st.subheader("Pacientes")

    # Loop para exibir os pacientes
    for paciente in pacientes:
        with st.expander(paciente["nome"], expanded=False):
            # Exibir informações do paciente
            st.write(f"**Nome**: {paciente['nome']}")
            st.write(f"**Idade**: {paciente['idade']}")
            st.write(f"**Data do AVC**: {paciente['DataAVC']}")

            # Exibir sessões do paciente
            st.write("### Sessões realizadas:")
            if paciente["id"] in sessions_data:
                for session in sessions_data[paciente["id"]]:
                    st.write(f"**Data**: {session['data']}")

                    # Nome do arquivo CSV fictício
                    file_name = f"{session['data'].replace('-', '')}-{paciente['id']}.csv"  # Formato do nome do arquivo
                    
                    # Criando link fictício para o download
                    st.markdown(f"[Baixar CSV: {file_name}](#)")
                    st.markdown(f"[Ver Relatório](#)")  # Link para a aba de relatórios (substitua pelo link correto)

                    st.write("---")  # Separador visual entre as sessões


if selected == "Minha Conta":
    st.subheader(f"{selected}")
    
    # Dados fictícios do usuário
    usuario_nome = "Dr. João Silva"
    usuario_email = "joao.silva@email.com"
    usuario_crefito = "12345-SP"
    
    # Definindo a data de entrada fixa
    data_entrada = "04/11/25"  # Data de entrada fixa como 04/11/25
        
    # Exibir as informações
    st.markdown("### Informações do Fisioterapeuta")
    st.markdown(f"- **Nome**: {usuario_nome}")
    st.markdown(f"- **E-mail**: {usuario_email}")
    st.markdown(f"- **CREFITO**: {usuario_crefito}")
    st.markdown(f"- **Data de Entrada**: {data_entrada}")

    # Botão para simular uma atualização de perfil
    if st.button('Atualizar Dados'):
        st.success("Dados atualizados com sucesso!")

    
if selected == "Contato":
    st.subheader(f"{selected}")
    
    # Seção de contatos da equipe
    st.write("Nossa equipe:")

    # E-mails dos membros da equipe
    st.markdown("### Equipe de Desenvolvimento")
    st.markdown("- **Arthur Laffitte**: [arthurdelaffitte@gmail.com](mailto:arthurdelaffitte@gmail.com)")
    st.markdown("- **Bruno Bellini**: [bruno.b.bellini@gmail.com](mailto:bruno.b.bellini@gmail.com)")
    st.markdown("- **Eduarda Klapper**: [duda.klapper@gmail.com](mailto:duda.klapper@gmail.com)")
    st.markdown("- **Francesco Trotta**: [ftrotta2@gmail.com](mailto:ftrotta2@gmail.com)")
    st.markdown("- **Guilherme Rossa**: [sc158542@gmail.com](mailto:sc158542@gmail.com)")
    st.markdown("- **Matheus Busnardo**: [matheus.busnardo@gmail.com](mailto:matheus.busnardo@gmail.com)")
    st.markdown("- **Vivian Guilger**: [vivianguilger@gmail.com](mailto:vivianguilger@gmail.com)")

    st.write("Caso precise de mais informações ou ajuda, entre em contato com qualquer membro da equipe!")
