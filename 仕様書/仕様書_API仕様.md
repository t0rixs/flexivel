# 仕様書 4/4：API仕様・クライアント挙動編（MVP）

## 1. API一覧（MVP）
- `POST /check`：15分おきの判定（ok/warn/broken）
- `POST /apply-option`：broken時のユーザー選択を反映し plan 更新
- `POST /enrich-plan`：予定入力を補完してFirestoreへ保存（運用次第で省略可）

---

## 2. POST /check

### 2.1 目的
- `userId` の plan をFirestoreから取得し、最も危険な1件について `ok/warn/broken` を返す。
- broken時は options（3択）を返し、Firestoreに `lastBroken` を上書き保存する。

### 2.2 Request
```ts
type CheckRequest = {
  userId: string;
  context: {
    now: string;         // ISO
    currentLat: number;
    currentLng: number;
  };
  transportMode: "transit";
};




### 2.3 Responsets
type CheckResponse = {
  status: "ok" | "warn" | "broken";

  // warn/brokenの対象（最も危険な1件）
  targetItemId?: string;

  // warn用（端末で通知文生成）
  minutesToDeadline?: number; // 切り捨て整数

  // broken用
  options?: BrokenOption[];   // GO_NEXT / DETOUR(candidates[3]) / SKIP
};




### 2.4 副作用（broken時のみ）
- users/{userId}.lastBroken を上書き保存
  - createdAt
  - targetItemId
  - options

---

## 3. POST /apply-option

### 3.1 目的
- broken時にユーザーが選んだ option を plan に反映し、更新済み plan を返す。
- 反映後は users/{userId}.plan を更新し、必要なら lastBroken をクリアする。

### 3.2 Requestts
type ApplyOptionRequest = {
  userId: string;
  targetItemId: string;  // /checkで返された broken 対象

  choice:
    | { kind: "GO_NEXT" }
    | { kind: "SKIP" }
    | { kind: "DETOUR"; detourPlaceId: string }; // lastBroken.options から復元

  transportMode: "transit";
};




### 3.3 Responsets
type ApplyOptionResponse = {
  status: "ok" | "error";
  updatedPlan?: Plan;     // サーバ側で再計算済みのPlan（端末は置換）
  message?: string;
};




### 3.4 サーバ側の適用ルール（MVP）
- GO_NEXT
  - planの実体更新は原則なし（必要なら内部状態更新）
  - updatedPlanは現行planを返してもよい
- SKIP
  - targetItemId の PlanItem を plan.items から削除
  - updatedPlan を返す
- DETOUR
  - Firestoreの lastBroken.options から detourPlaceId の候補を特定
  - targetItemId の PlanItem を、その候補内容で **置換**（insertではない）
  - updatedPlan を返す

※ updatedPlan.items[*].startTime の再計算方針はMVPでは厳密定義しない（必要なら後で追加）。

### 3.5 推奨の副作用
- choice適用成功後、`users/{userId}.lastBroken` をクリア（または上書き）して再発火を避ける。

---

## 4. POST /enrich-plan（入力補完）

### 4.1 目的
- ユーザー入力の予定を Places 等で補完し plan を構築して Firestore に保存する。

### 4.2 Request（例）ts
type EnrichPlanRequest = {
  userId: string;
  plan: {
    planId: string;
    createdAt: string;
    items: Array<{
      id: string;
      name: string;        // ユーザー入力
      startTime: string;   // ユーザー入力
      stayMinutes: number; // ユーザー入力
      // placeId/latlng/closeTime/deadlineは未入力でもよい
    }>;
    
  };
  transportMode: "transit";
};




### 4.3 Response（例）ts
type EnrichPlanResponse = {
  status: "ok" | "error";
  plan?: Plan;          // placeId/latlng/closeTime/deadline を埋めたPlan
  message?: string;
};




### 4.4 保存
- users/{userId}.plan を上書き保存
- updatedAt を更新

---

## 5. クライアント挙動（状態遷移）

### 5.1 定期チェック
- 15分おきに位置を取得し /check を呼ぶ
- 受信した status に応じて分岐：
  - ok：何もしない
  - warn：通知表示（minutesToDeadlineから文言生成）
  - broken：broken画面/モーダル表示（options表示）

### 5.2 broken UI
- options を表示
  - GO_NEXT ボタン
  - DETOUR：候補3件をリストで表示（住所・理由・開始時刻・滞在時間）
  - SKIP ボタン

### 5.3 適用
- ユーザー選択に応じて /apply-option 呼び出し
- updatedPlan を受信したら plan表示を更新
- 次の定期チェックへ戻る

---

## 6. 例外時の最低方針（MVP）
- planが存在しない：/checkは ok 返却 or error（実装方針で統一）
- closeTimeが無い予定：判定対象外（スキップ）
- lastBroken が無いのに DETOUR apply が来た：error（message返す）
- DETOUR候補が0件：broken optionsに DETOURを含めず GO_NEXT/SKIPのみ返す（許容）