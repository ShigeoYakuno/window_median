module median_filter_resource_optimized
(
    input                ck100m,
    input                srst_n,
    input                enable,       // データが有効なクロックで '1'
    input        [15:0]  in,
    output reg           out_enable,   // 中央値が出力されるクロックで '1'
    output reg   [15:0]  out           // 中央値 (レジスタ化された出力)
);

    // --- パラメータ定義 ---
    localparam int DEPTH = 11;
    localparam int MEDIAN_INDEX = DEPTH / 2;

    // --- ステートマシン定義 ---
    localparam [1:0] ST_IDLE   = 2'b00, // アイドル状態
                     ST_SORT   = 2'b01, // ソート実行中
                     ST_OUTPUT = 2'b10; // 結果出力
    
    reg [1:0] state;

    // --- 内部レジスタ定義 ---
    reg [15:0] window     [0:DEPTH-1]; // 最新データを保持するスライディングウィンドウ
    reg [15:0] sort_array [0:DEPTH-1]; // ソート処理用の作業配列
    reg [$clog2(DEPTH):0] sort_count;  // ソートの進捗を管理するカウンタ (0~9)

    // 1. スライディングウィンドウの更新 (常に動作)
    // enable信号をトリガーに、新しいデータを格納し古いデータをシフトアウトします。
    always @(posedge ck100m or negedge srst_n) begin
        if (~srst_n) begin
            for (int i = 0; i < DEPTH; i++) begin
                window[i] <= 16'd0;
            end
        end else if (enable) begin
            window[0] <= in;
            for (int i = 1; i < DEPTH; i++) begin
                window[i] <= window[i-1];
            end
        end
    end

    // 2. メインのステートマシンとデータ処理
    always @(posedge ck100m or negedge srst_n) begin
        if (~srst_n) begin
            state       <= ST_IDLE;
            sort_count  <= '0;
            out_enable  <= 1'b0;
            out         <= 16'd0;
            for (int i = 0; i < DEPTH; i++) sort_array[i] <= 16'd0;
        end else begin
            // デフォルトで出力を無効化
            out_enable <= 1'b0;

            case (state)
                // --- アイドル状態 ---
                ST_IDLE: begin
                    if (enable) begin
                        // 【修正2 & 修正4】
                        // ★ 最新 in を含むスナップショットで sort_array を初期化
                        sort_array[0] <= in;
                        for (int i = 1; i < DEPTH; i++) begin
                            sort_array[i] <= window[i-1];
                        end
                        sort_count <= '0;
                        state      <= ST_SORT;
                    end
                end

                // --- ソート実行状態 ---
                ST_SORT: begin
                    // Odd-Even ソートの 1 ステージ分を 1 クロックで実行
                    // 【修正1】procedural 内の一時変数は wire ではなく logic を使用
                    // 【修正3】偶奇判定は %2 ではなく LSB (sort_count[0]) で行う
                    for (int i = 0; i < (DEPTH/2); i++) begin
                        int idx1, idx2;
                        if (sort_count[0] == 1'b0) begin // Even Stage
                            idx1 = 2*i;
                            idx2 = 2*i + 1;
                        end else begin                 // Odd Stage
                            idx1 = 2*i + 1;
                            idx2 = 2*i + 2;
                        end

                        if (idx2 < DEPTH) begin
                            logic [15:0] d1, d2; // ← wire ではなく logic
                            d1 = sort_array[idx1];
                            d2 = sort_array[idx2];

                            // 比較と交換（NB 代入：同クロック内は旧値参照）
                            sort_array[idx1] <= (d1 <= d2) ? d1 : d2; // 小さい方
                            sort_array[idx2] <= (d1 <= d2) ? d2 : d1; // 大きい方
                        end
                    end
                    
                    sort_count <= sort_count + 1'b1;

                    // DEPTH回繰り返したらソート完了
                    if (sort_count == (DEPTH - 1)) begin
                        state <= ST_OUTPUT;
                    end
                end

                // --- 結果出力状態 ---
                ST_OUTPUT: begin
                    out        <= sort_array[MEDIAN_INDEX];
                    out_enable <= 1'b1;
                    state      <= ST_IDLE; // アイドル状態に戻り、次のenableを待つ
                end

                default: begin
                    state <= ST_IDLE;
                end
            endcase
        end
    end

endmodule
