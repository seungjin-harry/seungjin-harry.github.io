import os

chapters = {
    "chapter1_scope.html": ("제 1장: 개요 및 적용 범위", """
        <h1>제 1장: 개요 및 적용 범위 (Scope)</h1>
        <p>ETSI GS NFV-REL 003 규격의 목적과 가상화 네트워크 환경에서의 신뢰성 보장 기본 철학을 정의합니다.</p>
        <ul>
            <li><strong>문서 목적:</strong> NFV(Network Functions Virtualisation) 환경에서 엔드투엔드(End-to-End) 신뢰성 및 가용성을 달성하기 위한 모델, 아키텍처 및 방법론 제시</li>
            <li><strong>적용 범위:</strong> 하부 물리 인프라(NFVI), 가상화 관리 계층(VIM/MANO), 그리고 상위 VNF 및 네트워크 서비스(NS) 전반</li>
        </ul>
    """),
    "chapter2_modeling.html": ("제 2장: 신뢰성 모델링 아키텍처", """
        <h1>제 2장: 신뢰성 모델링 아키텍처 및 평가 방법론</h1>
        <p>멀티 레이어 환경에서의 종속성 분석 및 정량적 신뢰성 평가 모델을 다룹니다.</p>
        <ul>
            <li><strong>컴포넌트 의존성 그래프:</strong> VNF 구성 요소(VNFC)와 물리 서버, 스토리지 간의 계층적 종속 관계 분석</li>
            <li><strong>정량적 평가 모델:</strong> 마르코프 체인(Markov Chain) 및 신뢰도 블록 다이어그램(RBD)을 활용한 고장률(λ) 및 복구율(MTTR) 연산</li>
            <li><strong>안티-콜로케이션(Anti-colocation):</strong> 이중화 대상 VNF 인스턴스가 동일 물리 랙에 동시 배치되는 것을 방지하는 규칙</li>
        </ul>
    """),
    "chapter3_dynamic.html": ("제 3장: 동적 운영 환경 분석", """
        <h1>제 3장: 동적 운영 환경 및 부하 의존성 분석</h1>
        <p>실시간 트래픽 변동과 라이프사이클 관리(LCM) 이벤트가 신뢰도에 미치는 영향을 분석합니다.</p>
        <ul>
            <li><strong>부하 종속적 장애 모델:</strong> 트래픽 폭증 시 자원 과부하로 인한 VNF 내부 오류율 비선형 증가 현상 모델링</li>
            <li><strong>LCM 영향 제어:</strong> 오토스케일링 및 라이브 마이그레이션 중 제어 플레인 지연이 서비스에 미치는 리스크 제어</li>
            <li><strong>실시간 신뢰도 추정:</strong> 텔레메트리 데이터를 통한 인프라 잔여 신뢰도(Confidence Score) 실시간 산출</li>
        </ul>
    """),
    "chapter4_upgrade.html": ("제 4장: 소프트웨어 업그레이드 복원력", """
        <h1>제 4장: VNF 소프트웨어 업그레이드 및 복원력 메커니즘</h1>
        <p>계획된 인위적 장애인 소프트웨어 갱신 과정에서의 무중단 서비스 연속성 확보 방안을 규정합니다.</p>
        <ul>
            <li><strong>상태 비저장(Stateless) 분리:</strong> 세션 정보를 외부 분산 DB에 격리하여 인스턴스 재시작 시 세션 유실 방지</li>
            <li><strong>롤링 업그레이드(Rolling Upgrade):</strong> 트래픽 드레이닝(Draining)을 통한 세션 우회 및 순차적 갱신</li>
            <li><strong>자동 롤백(Automatic Rollback):</strong> 헬스체크 실패 시 이전 버전으로 즉시 원상복구하는 오케스트레이션 절차</li>
        </ul>
    """),
    "chapter5_differentiation.html": ("제 5장: 복원력 차별화 및 정책", """
        <h1>제 5장: 복원력 차별화 및 정책 관리</h1>
        <p>서비스 요구사항(SLA)에 따른 맞춤형 복원력 클래스 부여 및 정책 기반 오케스트레이션을 다룹니다.</p>
        <ul>
            <li><strong>가용성 등급 세분화:</strong> Class 0(미션 크리티컬, 액티브-액티브 이중화), Class 1(고신뢰, N+K 리던던시), Class 2(일반, 자동 재시작)</li>
            <li><strong>정책 바인딩:</strong> 서비스 디스크립터에 복원력 메타데이터를 포함시켜 MANO가 자원을 자동 바인딩하도록 설계</li>
        </ul>
    """)
}

base_template = """<!DOCTYPE html>
<html lang="ko">
<head>
    <meta charset="UTF-8">
    <title>ETSI GS NFV-REL 003 - {title}</title>
    <style>
        body {{ font-family: 'Malgun Gothic', sans-serif; line-height: 1.8; color: #1e293b; max-width: 900px; margin: 0 auto; padding: 40px; background-color: #f8fafc; }}
        header {{ background: #0f172a; color: white; padding: 30px; border-radius: 8px; text-align: center; margin-bottom: 30px; }}
        .content {{ background: white; padding: 40px; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.05); }}
        h1 {{ color: #0f172a; border-bottom: 3px solid #0284c7; padding-bottom: 10px; }}
        ul {{ padding-left: 20px; }}
        li {{ margin-bottom: 10px; }}
        .nav {{ margin-top: 20px; text-align: center; }}
        .nav a {{ color: #0284c7; text-decoration: none; font-weight: bold; }}
    </style>
</head>
<body>
    <header>
        <h2>ETSI GS NFV-REL 003 상세 규격 문서</h2>
    </header>
    <div class="content">
        {content}
    </div>
</body>
</html>
"""

for filename, (title, html_content) in chapters.items():
    full_html = base_template.format(title=title, content=html_content)
    with open(filename, "w", encoding="utf-8") as f:
        f.write(full_html)
    print(f"생성 완료: {filename}")
