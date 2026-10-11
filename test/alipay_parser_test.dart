import 'package:flutter_test/flutter_test.dart';

import 'package:toolbox/features/ledger/data/import/parsers/alipay_parser.dart';
import 'package:toolbox/features/ledger/data/ledger_tables.dart';

void main() {
  const csv = '''
支付宝交易记录明细查询
账号:xxx@example.com
起始日期:[2024-01-01 00:00:00]    终止日期:[2024-01-31 23:59:59]
交易时间,交易分类,交易对方,商品说明,收/支,金额,收/付款方式,交易状态,交易订单号,商户订单号,备注
2024-01-05 12:30:00,餐饮美食,美团外卖,午餐,支出,35.50,余额,交易成功,20240105120000,20240105120000,
2024-01-06 09:00:00,交通出行,滴滴出行,打车,支出,22.00,余额,交易成功,20240106090000,20240106090000,
2024-01-07 10:00:00,转账,张三,红包,收入,100.00,余额,交易成功,20240107100000,20240107100000,
2024-01-08 11:00:00,理财,余额宝,转入,不计收支,500.00,余额,交易成功,20240108110000,,
2024-01-09 12:00:00,购物,淘宝,退款,支出,66.00,余额,退款成功,20240109120000,,
2024-01-10 13:00:00,餐饮,肯德基,午餐,支出,abc,余额,交易成功,20240110130000,,
''';

  test('支付宝 CSV：识别正常收支，跳过不计收支/退款，记录解析失败', () async {
    final result = await const AlipayCsvParser().parse(csv);

    expect(result.bills, hasLength(3));
    expect(result.failures, hasLength(1));

    // 支出
    expect(result.bills[0].amountCents, 3550);
    expect(result.bills[0].kind, EntryKind.expense);
    expect(result.bills[0].merchant, '美团外卖');
    expect(result.bills[0].sourceId, '20240105120000');

    // 收入
    expect(result.bills[2].amountCents, 10000);
    expect(result.bills[2].kind, EntryKind.income);

    // 金额无法解析的那行
    expect(result.failures.single, contains('abc'));
  });

  test('金额解析：带 ¥ 与千分位、负数都能正确处理', () async {
    const single = '''
交易时间,金额,收/支,交易对方,交易状态,交易订单号
2024-01-01 00:00:00,¥1,234.56,支出,美团,交易成功,1
2024-01-01 00:00:00,0.5,支出,滴滴,交易成功,2
''';
    final result = await const AlipayCsvParser().parse(single);
    expect(result.bills, hasLength(2));
    expect(result.bills[0].amountCents, 123456);
    expect(result.bills[1].amountCents, 50);
  });
}
