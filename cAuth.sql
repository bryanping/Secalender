-- phpMyAdmin SQL Dump
-- version 4.5.4.1deb2ubuntu2.1
-- http://www.phpmyadmin.net
--
-- 主機: localhost
-- 產生時間： 2025 年 06 月 26 日 13:59
-- 伺服器版本: 5.7.26-0ubuntu0.16.04.1
-- PHP 版本： 7.0.33-0ubuntu0.16.04.3

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- 資料庫： `cAuth`
--

-- --------------------------------------------------------

--
-- 資料表結構 `cAppinfo`
--

CREATE TABLE `cAppinfo` (
  `appid` char(36) DEFAULT NULL,
  `secret` char(64) DEFAULT NULL,
  `ip` char(20) DEFAULT NULL,
  `login_duration` int(11) DEFAULT NULL,
  `qcloud_appid` char(64) DEFAULT NULL,
  `session_duration` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- 資料表的匯出資料 `cAppinfo`
--

INSERT INTO `cAppinfo` (`appid`, `secret`, `ip`, `login_duration`, `qcloud_appid`, `session_duration`) VALUES
('wxac1f33bcb2f4e746', '', '118.25.20.4', 1000, '1256097782', 2000);

-- --------------------------------------------------------

--
-- 資料表結構 `cSessionInfo`
--

CREATE TABLE `cSessionInfo` (
  `open_id` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `uuid` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `skey` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `create_time` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `last_visit_time` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `session_key` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `user_info` varchar(2048) COLLATE utf8mb4_unicode_ci NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='会话管理用户信息';

--
-- 資料表的匯出資料 `cSessionInfo`
--

INSERT INTO `cSessionInfo` (`open_id`, `uuid`, `skey`, `create_time`, `last_visit_time`, `session_key`, `user_info`) VALUES
('999', '999', '999', '2018-07-26 13:08:47', '2018-07-26 13:08:47', '999', '999'),
('oIdsD5gp0GE3iKNdi1tqi1al5RIg', '84fb20f3-12e2-44cd-a8c3-11cb519757bb', 'c8fbf9ffc4a2f9647c8e72270e6f0924b57a2e44', '2018-08-18 08:52:06', '2018-08-18 08:52:06', '5Pl3W2+cZ12wrGy53o+ykg==', '{"openId":"oIdsD5gp0GE3iKNdi1tqi1al5RIg","nickName":"林平🐉 活動历","gender":1,"language":"zh_TW","city":"New Taipei City","province":"Taiwan","country":"China","avatarUrl":"https://wx.qlogo.cn/mmopen/vi_32/SNGMbcoFn0BFEbZuVTRNxLLT7LR14LsIdMDaDsibDMicHMeK5yzsjSjCiaKOeH58QiblcjwL3CGOj09qXC0TAIiaxMw/132","watermark":{"timestamp":1534582324,"appid":"wx9814cfc5cf43159d"}}');

-- --------------------------------------------------------

--
-- 資料表結構 `event`
--

CREATE TABLE `event` (
  `id` int(12) NOT NULL,
  `title` text COLLATE utf8mb4_unicode_ci,
  `creator_openid` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `color` varchar(12) COLLATE utf8mb4_unicode_ci NOT NULL,
  `date` date NOT NULL,
  `start_time` time NOT NULL,
  `end_time` time NOT NULL,
  `destination` text COLLATE utf8mb4_unicode_ci,
  `mapObj` text COLLATE utf8mb4_unicode_ci,
  `openChecked` int(11) DEFAULT '0',
  `personChecked` int(11) DEFAULT '0',
  `personNumber` int(11) DEFAULT NULL,
  `sponsorType` varchar(10) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `category` varchar(10) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `create_time` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `deleted` tinyint(1) DEFAULT NULL,
  `information` text COLLATE utf8mb4_unicode_ci
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- 資料表的匯出資料 `event`
--

INSERT INTO `event` (`id`, `title`, `creator_openid`, `color`, `date`, `start_time`, `end_time`, `destination`, `mapObj`, `openChecked`, `personChecked`, `personNumber`, `sponsorType`, `category`, `create_time`, `deleted`, `information`) VALUES
(2123, '新天地沙龙（小夜灯）', 'opqVH4wrsPcBtnUm1U8S4w9NhFT8', 'ff6280', '2025-05-15', '09:00:00', '11:00:00', '中国工商银行(大连新天地支行)', '{"longitude":121.58647155761719,"latitude":38.91657257080078,"address":"辽宁省大连市沙河口区西安路99号福佳新天地广场(西安路店)F1","markers":[{"iconPath":"../../../../img/UI-3i@3x.png","longitude":121.58647155761719,"latitude":38.91657257080078,"width":25,"height":25}]}', 0, 0, NULL, NULL, NULL, '2025-05-07 07:14:47', NULL, NULL),
(2124, '锦绣沙龙（小夜灯）', 'opqVH4wrsPcBtnUm1U8S4w9NhFT8', 'ff6280', '2025-05-15', '13:30:00', '16:00:00', '中国工商银行(大连锦绣支行)', '{"longitude":121.55447387695312,"latitude":38.94215393066406,"address":"辽宁省大连市沙河口区李家街道锦绣小区锦石路2号","markers":[{"iconPath":"../../../../img/UI-3i@3x.png","longitude":121.55447387695312,"latitude":38.94215393066406,"width":25,"height":25}]}', 0, 0, NULL, NULL, NULL, '2025-05-07 07:17:16', NULL, NULL),
(2125, '玉华沙龙（小夜灯）', 'opqVH4wrsPcBtnUm1U8S4w9NhFT8', 'ff6280', '2025-05-07', '13:30:00', '16:00:00', '中国工商银行(大连玉华支行)', '{"longitude":121.59871673583984,"latitude":38.90773391723633,"address":"辽宁省大连市沙河口区西安路街道五一路13号","markers":[{"iconPath":"../../../../img/UI-3i@3x.png","longitude":121.59871673583984,"latitude":38.90773391723633,"width":25,"height":25}]}', 0, 0, NULL, NULL, NULL, '2025-05-07 07:19:26', 1, NULL),
(2126, '玉华沙龙（小夜灯）', 'opqVH4wrsPcBtnUm1U8S4w9NhFT8', 'ff6280', '2025-05-16', '13:30:00', '16:00:00', '中国工商银行(大连玉华支行)', '{"longitude":121.59871673583984,"latitude":38.90773391723633,"address":"辽宁省大连市沙河口区西安路街道五一路13号","markers":[{"iconPath":"../../../../img/UI-3i@3x.png","longitude":121.59871673583984,"latitude":38.90773391723633,"width":25,"height":25}]}', 0, 0, NULL, NULL, NULL, '2025-05-07 07:21:33', 1, NULL),
(2127, '和平沙龙（小夜灯）', 'opqVH4wrsPcBtnUm1U8S4w9NhFT8', 'ff6280', '2025-05-20', '13:30:00', '16:00:00', '中国工商银行(大连和平广场支行)', '{"longitude":121.58720397949219,"latitude":38.89578628540039,"address":"辽宁省大连市沙河口区高尔基路737号","markers":[{"iconPath":"../../../../img/UI-3i@3x.png","longitude":121.58720397949219,"latitude":38.89578628540039,"width":25,"height":25}]}', 0, 0, NULL, NULL, NULL, '2025-05-07 07:23:23', NULL, NULL),
(2128, '大庆沙龙（小夜灯）', 'opqVH4wrsPcBtnUm1U8S4w9NhFT8', 'ff6280', '2025-05-22', '13:30:00', '16:00:00', '中国工商银行(大连大庆支行)', '{"longitude":121.57362365722656,"latitude":38.9207878112793,"address":"辽宁省大连市沙河口区马栏街道西山街6号","markers":[{"iconPath":"../../../../img/UI-3i@3x.png","longitude":121.57362365722656,"latitude":38.9207878112793,"width":25,"height":25}]}', 0, 0, NULL, NULL, NULL, '2025-05-07 07:25:39', NULL, NULL),
(2129, '营业部沙龙（小夜灯）', 'opqVH4wrsPcBtnUm1U8S4w9NhFT8', 'ff6280', '2025-05-23', '13:30:00', '16:00:00', '中国工商银行(大连沙河口支行营业部)', '{"longitude":121.58952331542969,"latitude":38.912662506103516,"address":"辽宁省大连市沙河口区成仁街1号","markers":[{"iconPath":"../../../../img/UI-3i@3x.png","longitude":121.58952331542969,"latitude":38.912662506103516,"width":25,"height":25}]}', 0, 0, NULL, NULL, NULL, '2025-05-07 07:28:24', NULL, NULL),
(2130, '中山路沙龙（小夜灯）', 'opqVH4wrsPcBtnUm1U8S4w9NhFT8', 'ff6280', '2025-05-29', '13:30:00', '16:00:00', '中国工商银行24小时自助银行(大连中山路支行)', '{"longitude":121.59178924560547,"latitude":38.902374267578125,"address":"辽宁省大连市沙河口区星海湾街道中山路494号","markers":[{"iconPath":"../../../../img/UI-3i@3x.png","longitude":121.59178924560547,"latitude":38.902374267578125,"width":25,"height":25}]}', 0, 0, NULL, NULL, NULL, '2025-05-07 07:29:37', NULL, NULL),
(2131, '锦程沙龙（小夜灯）', 'opqVH4wrsPcBtnUm1U8S4w9NhFT8', 'ff6280', '2025-05-09', '13:30:00', '16:30:00', '中国工商银行24小时自助银行(大连锦程支行)', '{"longitude":121.54513549804688,"latitude":38.941627502441406,"address":"辽宁省大连市沙河口区李家街道锦绣路115号","markers":[{"iconPath":"../../../../img/UI-3i@3x.png","longitude":121.54513549804688,"latitude":38.941627502441406,"width":25,"height":25}]}', 0, 0, NULL, NULL, NULL, '2025-05-07 07:56:31', 1, NULL),
(2132, '玉华沙龙', 'opqVH4wrsPcBtnUm1U8S4w9NhFT8', 'ff6280', '2025-05-26', '13:00:00', '16:00:00', '中国工商银行(大连玉华支行)', '{"longitude":121.59871673583984,"latitude":38.90773391723633,"address":"辽宁省大连市沙河口区西安路街道五一路13号","markers":[{"iconPath":"../../../../img/UI-3i@3x.png","longitude":121.59871673583984,"latitude":38.90773391723633,"width":25,"height":25}]}', 0, 0, NULL, NULL, NULL, '2025-05-08 06:22:00', NULL, NULL),
(2133, '益嘉沙龙（小夜灯）', 'opqVH4wrsPcBtnUm1U8S4w9NhFT8', 'ff6280', '2025-05-27', '13:00:00', '16:00:00', '中国工商银行(益嘉广场支行)', '{"longitude":121.55538940429688,"latitude":38.919219970703125,"address":"辽宁省大连市沙河口区黄河路916,918号","markers":[{"iconPath":"../../../../img/UI-3i@3x.png","longitude":121.55538940429688,"latitude":38.919219970703125,"width":25,"height":25}]}', 0, 0, NULL, NULL, NULL, '2025-05-08 06:23:28', NULL, NULL),
(2134, '锦程沙龙（小夜灯）', 'opqVH4wrsPcBtnUm1U8S4w9NhFT8', 'ff6280', '2025-05-22', '09:00:00', '09:00:00', '中国工商银行(大连锦程支行)', '{"longitude":121.54544830322266,"latitude":38.94157791137695,"address":"辽宁省大连市沙河口区李家街道锦绣路115号","markers":[{"iconPath":"../../../../img/UI-3i@3x.png","longitude":121.54544830322266,"latitude":38.94157791137695,"width":25,"height":25}]}', 0, 0, NULL, NULL, NULL, '2025-05-08 09:08:46', NULL, NULL),
(2135, '龙王塘沙龙（小夜灯）', 'opqVH4wrsPcBtnUm1U8S4w9NhFT8', 'ff6280', '2025-05-12', '09:00:00', '11:00:00', '大连农商银行(龙王塘支行)', '{"longitude":121.40036010742188,"latitude":38.841705322265625,"address":"辽宁省大连市旅顺口区高新园区龙王塘街道官房村","markers":[{"iconPath":"../../../../img/UI-3i@3x.png","longitude":121.40036010742188,"latitude":38.841705322265625,"width":25,"height":25}]}', 0, 0, NULL, NULL, NULL, '2025-05-09 01:43:14', NULL, NULL),
(2136, '营业区早会', 'opqVH4wMC9K08B1sN5fT6WdDdvdc', 'ff6280', '2025-05-20', '07:30:00', '09:30:00', '海尔·时代大厦', '{"longitude":117.06693,"latitude":36.650173,"address":"山东省济南市历下区经十路14380号(燕山立交西南角)","markers":[{"iconPath":"../../../../img/UI-3i@3x.png","longitude":117.06693,"latitude":36.650173,"width":25,"height":25}]}', 0, 0, NULL, NULL, NULL, '2025-05-19 13:31:50', NULL, NULL),
(2137, 'EMP座谈会', 'opqVH4wMC9K08B1sN5fT6WdDdvdc', 'ff6280', '2025-05-20', '10:00:00', '10:00:00', '历下区奥体公园世纪东区(天泺路东50米)', '{"longitude":117.12112,"latitude":36.677742,"address":"山东省济南市历下区天泺路","markers":[{"iconPath":"../../../../img/UI-3i@3x.png","longitude":117.12112,"latitude":36.677742,"width":25,"height":25}]}', 0, 0, NULL, NULL, NULL, '2025-05-19 13:32:36', NULL, NULL),
(2138, '职场活动1+2林姐', 'opqVH4wMC9K08B1sN5fT6WdDdvdc', 'ff6280', '2025-05-20', '13:00:00', '13:00:00', '海尔·时代大厦', '{"longitude":117.06693,"latitude":36.650173,"address":"山东省济南市历下区经十路14380号(燕山立交西南角)","markers":[{"iconPath":"../../../../img/UI-3i@3x.png","longitude":117.06693,"latitude":36.650173,"width":25,"height":25}]}', 0, 0, NULL, NULL, NULL, '2025-05-19 13:33:23', NULL, NULL),
(2139, '火锅卤培训', 'opqVH44U39w0kohLrbAecS19TSTE', 'ff6280', '2025-06-09', '22:09:00', '23:09:00', '望月公寓', '{"longitude":120.09069,"latitude":30.312223,"address":"浙江省杭州市西湖区三敦望月公寓(浙大紫荆港校区附近)","markers":[{"iconPath":"../../../../img/UI-3i@3x.png","longitude":120.09069,"latitude":30.312223,"width":25,"height":25}]}', 0, 0, NULL, NULL, NULL, '2025-06-09 14:09:54', NULL, NULL),
(2140, '火锅卤培训', 'opqVH44U39w0kohLrbAecS19TSTE', 'ff6280', '2025-06-09', '22:09:00', '22:09:00', '望月公寓', '{"longitude":120.09069,"latitude":30.312223,"address":"浙江省杭州市西湖区三敦望月公寓(浙大紫荆港校区附近)","markers":[{"iconPath":"../../../../img/UI-3i@3x.png","longitude":120.09069,"latitude":30.312223,"width":25,"height":25}]}', 0, 0, NULL, NULL, NULL, '2025-06-09 14:10:42', 1, NULL),
(2141, '嘻嘻嘻', 'opqVH4z_dxfnkGmI-3i4Y-d9tyfY', 'ff6280', '2025-06-12', '11:54:00', '12:54:00', 'Emas Software', '{"longitude":100.41108,"latitude":5.4061,"address":"Emas Software, Lorong Seri Arowana 1, Taman Arowana, 13500 Seberang Jaya, Pulau Pinang, Malaysia","markers":[{"iconPath":"../../../../img/UI-3i@3x.png","longitude":100.41108,"latitude":5.4061,"width":25,"height":25}]}', 0, 0, NULL, NULL, NULL, '2025-06-11 03:55:09', NULL, NULL),
(2142, '汪爱莲——平台', 'opqVH4_Q1kxm8OAyz-7QrAihZaTk', 'ff6280', '2025-06-20', '09:00:00', '09:11:00', '郴州市二十九完小北(健康路)', '{"longitude":113.03783,"latitude":25.801062,"address":"湖南省郴州市苏仙区苏园西路9-21号","markers":[{"iconPath":"../../../../img/UI-3i@3x.png","longitude":113.03783,"latitude":25.801062,"width":25,"height":25}]}', 0, 0, NULL, NULL, NULL, '2025-06-19 07:18:30', 1, NULL);

-- --------------------------------------------------------

--
-- 資料表結構 `event_invite`
--

CREATE TABLE `event_invite` (
  `id` int(11) NOT NULL,
  `event_id` int(11) NOT NULL,
  `invited_openid` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `status` tinyint(1) DEFAULT NULL,
  `create_time` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- 資料表的匯出資料 `event_invite`
--

INSERT INTO `event_invite` (`id`, `event_id`, `invited_openid`, `status`, `create_time`) VALUES
(1, 2, 'oIdsD5lrmTYO38XcfMofdNQ607PA', 1, '2018-08-08 12:48:00'),
(2, 3, 'oIdsD5n1HdGED3RXcReuZlcFWm0g', 1, '2018-08-08 13:01:56'),
(4, 30, 'oIdsD5n1HdGED3RXcReuZlcFWm0g', 1, '2018-08-08 13:10:14'),
(5, 14, 'oIdsD5n1HdGED3RXcReuZlcFWm0g', 1, '2018-08-10 09:47:32'),
(6, 39, 'oIdsD5n1HdGED3RXcReuZlcFWm0g', 1, '2018-08-10 10:15:49'),
(7, 40, 'oIdsD5n1HdGED3RXcReuZlcFWm0g', 1, '2018-08-10 10:55:28'),
(8, 41, 'oIdsD5n1HdGED3RXcReuZlcFWm0g', 1, '2018-08-10 10:55:41'),
(738, 1033, 'opqVH43U8lZeD6B1gRdfcS8vjEsU', 1, '2019-12-11 03:52:41'),
(739, 1034, 'opqVH43U8lZeD6B1gRdfcS8vjEsU', 1, '2019-12-11 03:52:41'),
(740, 1035, 'opqVH43U8lZeD6B1gRdfcS8vjEsU', 1, '2019-12-11 03:52:41');
INSERT INTO `event_invite` (`id`, `event_id`, `invited_openid`, `status`, `create_time`) VALUES
(741, 1026, 'opqVH402jOnbDyD0qtgaSiGxdukU', 1, '2019-12-11 07:22:38'),
(789, 1026, 'opqVH47WLv4eKw4RZ0Z_VLnBx6TQ', 1, '2019-12-14 01:07:16'),
(790, 1026, 'opqVH41s6NfEycJSpZzQxQ2NmQME', 1, '2019-12-14 02:41:00'),
(791, 1026, 'opqVH4_uxr2f8YJoki21PnP7E4PE', 1, '2019-12-14 03:21:17'),
(792, 2083, 'opqVH41yJdUyhrOtx4iwSZ1mdkhs', 1, '2020-03-30 17:22:50'),
(793, 2089, 'opqVH40xuqjhVsqn1JadmbE-SzFY', 1, '2024-07-19 03:42:42'),
(794, 2099, 'opqVH478fBIyXyaUBnHU9wOPTEy4', 1, '2024-07-24 06:29:13'),
(795, 2100, 'opqVH40xuqjhVsqn1JadmbE-SzFY', 1, '2024-07-24 06:55:33'),
(796, 2101, 'opqVH40xuqjhVsqn1JadmbE-SzFY', 1, '2024-07-31 07:14:32'),
(797, 2104, 'opqVH40xuqjhVsqn1JadmbE-SzFY', 1, '2024-08-01 01:16:15'),
(798, 2102, 'opqVH40xuqjhVsqn1JadmbE-SzFY', 1, '2024-08-01 13:15:40'),
(799, 2107, 'opqVH4xP4f8Ffo0QM3A6BJV3BWZM', 1, '2024-08-04 06:36:05');

-- --------------------------------------------------------

--
-- 資料表結構 `group`
--

CREATE TABLE `group` (
  `id` int(11) NOT NULL,
  `title` text COLLATE utf8mb4_unicode_ci,
  `creator_openid` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `category` varchar(10) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `mapObj` text COLLATE utf8mb4_unicode_ci,
  `followType` int(11) DEFAULT NULL,
  `information` text COLLATE utf8mb4_unicode_ci,
  `create_time` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `deleted` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- 資料表結構 `testTableResponse`
--

CREATE TABLE `testTableResponse` (
  `id` int(11) NOT NULL,
  `textVal` text COLLATE utf8mb4_unicode_ci NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- 資料表的匯出資料 `testTableResponse`
--

INSERT INTO `testTableResponse` (`id`, `textVal`) VALUES
(13, '{"nickName":"Artem A.","gender":0,"language":"ru","city":"","province":"","country":"","avatarUrl":""}'),
(14, '{"nickName":"Vladislav Khorev","gender":0,"language":"ru","city":"","province":"","country":"","avatarUrl":"https://wx.qlogo.cn/mmopen/vi_32/uDjPS3kNF4hT6vicTF63YibSSEhBcN8vzUPydVQqFulmpkC5Hfm9sC7XX6HkzicPDDaV1rYp5ciasR0hCKVcCEHWuw/132"}'),
(15, '{"nickName":"林平🐉 活動历","gender":1,"language":"zh_TW","city":"New Taipei City","province":"Taiwan","country":"China","avatarUrl":"https://wx.qlogo.cn/mmopen/vi_32/SNGMbcoFn0BFEbZuVTRNxLLT7LR14LsIdMDaDsibDMicHMeK5yzsjSjCiaKOeH58QiblcjwL3CGOj09qXC0TAIiaxMw/132"}'),
(211, '{"nickName":"吳小小兒","gender":2,"language":"zh_TW","city":"Taipei","province":"Taiwan","country":"China","avatarUrl":"https://wx.qlogo.cn/mmopen/vi_32/PiajxSqBRaEI7cUnQcZ7OaoLW0XlickI6sfePnxaTO4X4RHn7MbdJRianmv1COx3MiaT7RvAQpyhXF4SveT0GXKfqQ/132"}'),
(212, '{"nickName":"Mia","gender":2,"language":"zh_CN","city":"Taichung City","province":"Taiwan","country":"China","avatarUrl":"https://wx.qlogo.cn/mmopen/vi_32/Q0j4TwGTfTJxic9C0IaSdAfe1MmicosD3D6OebQU0Eib1Io3f7OWicaiaJTbtO6b8gQRrar3wszm1dZppyrXSkWzdVQ/132"}');
INSERT INTO `testTableResponse` (`id`, `textVal`) VALUES
(2283, '{"nickName":"微信用户","gender":0,"language":"","city":"","province":"","country":"","avatarUrl":"https://thirdwx.qlogo.cn/mmopen/vi_32/POgEwh4mIHO4nibH0KlMECNjjGxQUq24ZEaGT4poC6icRiccVGKSyXwibcPq4BWmiaIGuG1icwxaQX6grC9VemZoJ8rg/132"}'),
(2284, '{"nickName":"微信用户","gender":0,"language":"","city":"","province":"","country":"","avatarUrl":"https://thirdwx.qlogo.cn/mmopen/vi_32/POgEwh4mIHO4nibH0KlMECNjjGxQUq24ZEaGT4poC6icRiccVGKSyXwibcPq4BWmiaIGuG1icwxaQX6grC9VemZoJ8rg/132"}'),
(2285, '{"nickName":"微信用户","gender":0,"language":"","city":"","province":"","country":"","avatarUrl":"https://thirdwx.qlogo.cn/mmopen/vi_32/POgEwh4mIHO4nibH0KlMECNjjGxQUq24ZEaGT4poC6icRiccVGKSyXwibcPq4BWmiaIGuG1icwxaQX6grC9VemZoJ8rg/132"}');

-- --------------------------------------------------------

--
-- 資料表結構 `token`
--

CREATE TABLE `token` (
  `openid` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `code` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `expire` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- 資料表的匯出資料 `token`
--

INSERT INTO `token` (`openid`, `code`, `expire`) VALUES
('oIdsD5g_3V2mMerG1QTsnxJB5xzI', 'NOUVvppi7VP0', '2019-05-01 02:35:21'),
('opqVH4zZO5Zlw3pzD0O4QbF2WVEo', 'QwrGEUQQHQYO', '2019-10-08 07:12:36');

-- --------------------------------------------------------

--
-- 資料表結構 `user`
--

CREATE TABLE `user` (
  `id` int(11) NOT NULL,
  `openid` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `nickName` text COLLATE utf8mb4_unicode_ci NOT NULL,
  `avatarUrl` text COLLATE utf8mb4_unicode_ci NOT NULL,
  `gender` int(11) NOT NULL,
  `province` text COLLATE utf8mb4_unicode_ci,
  `city` text COLLATE utf8mb4_unicode_ci,
  `country` text COLLATE utf8mb4_unicode_ci,
  `create_time` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `last_visit_time` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `last_session_key` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- 資料表的匯出資料 `user`
--

INSERT INTO `user` (`id`, `openid`, `nickName`, `avatarUrl`, `gender`, `province`, `city`, `country`, `create_time`, `last_visit_time`, `last_session_key`) VALUES
(1, 'oIdsD5lrmTYO38XcfMofdNQ607PA', 'Vladislav Khorev', 'https://wx.qlogo.cn/mmopen/vi_32/uDjPS3kNF4hT6vicTF63YibSSEhBcN8vzUPydVQqFulmpkC5Hfm9sC7XX6HkzicPDDaV1rYp5ciasR0hCKVcCEHWuw/132', 0, '', '', '', '2018-07-26 17:29:03', '2018-08-20 11:46:21', 'O3nEQr8ecKEoJj0lrlgWLQ=='),
(2274, 'opqVH4-8tNwchNENh7aHiBQkWwH0', '微信用户', 'https://thirdwx.qlogo.cn/mmopen/vi_32/POgEwh4mIHO4nibH0KlMECNjjGxQUq24ZEaGT4poC6icRiccVGKSyXwibcPq4BWmiaIGuG1icwxaQX6grC9VemZoJ8rg/132', 0, '', '', '', '2025-06-17 12:16:31', '2025-06-17 12:16:31', '9dGQ6T7R21j2Oq5Xp0vKlw=='),
(2275, 'opqVH4_Q1kxm8OAyz-7QrAihZaTk', '微信用户', 'https://thirdwx.qlogo.cn/mmopen/vi_32/POgEwh4mIHO4nibH0KlMECNjjGxQUq24ZEaGT4poC6icRiccVGKSyXwibcPq4BWmiaIGuG1icwxaQX6grC9VemZoJ8rg/132', 0, '', '', '', '2025-06-19 07:16:54', '2025-06-19 07:16:54', '4IJXgqgFrDRAquYVvhRqpw==');

--
-- 已匯出資料表的索引
--

--
-- 資料表索引 `cSessionInfo`
--
ALTER TABLE `cSessionInfo`
  ADD PRIMARY KEY (`open_id`),
  ADD KEY `openid` (`open_id`) USING BTREE,
  ADD KEY `skey` (`skey`) USING BTREE;

--
-- 資料表索引 `event`
--
ALTER TABLE `event`
  ADD PRIMARY KEY (`id`),
  ADD KEY `id` (`id`) USING BTREE;

--
-- 資料表索引 `event_invite`
--
ALTER TABLE `event_invite`
  ADD PRIMARY KEY (`id`),
  ADD KEY `event_id` (`event_id`),
  ADD KEY `id` (`id`) USING BTREE;

--
-- 資料表索引 `group`
--
ALTER TABLE `group`
  ADD PRIMARY KEY (`id`);

--
-- 資料表索引 `testTableResponse`
--
ALTER TABLE `testTableResponse`
  ADD PRIMARY KEY (`id`);

--
-- 資料表索引 `token`
--
ALTER TABLE `token`
  ADD PRIMARY KEY (`openid`),
  ADD KEY `openid` (`openid`) USING BTREE;

--
-- 資料表索引 `user`
--
ALTER TABLE `user`
  ADD PRIMARY KEY (`id`),
  ADD KEY `openid` (`openid`) USING BTREE;

--
-- 在匯出的資料表使用 AUTO_INCREMENT
--

--
-- 使用資料表 AUTO_INCREMENT `event`
--
ALTER TABLE `event`
  MODIFY `id` int(12) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2143;
--
-- 使用資料表 AUTO_INCREMENT `event_invite`
--
ALTER TABLE `event_invite`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=800;
--
-- 使用資料表 AUTO_INCREMENT `testTableResponse`
--
ALTER TABLE `testTableResponse`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2286;
--
-- 使用資料表 AUTO_INCREMENT `user`
--
ALTER TABLE `user`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2276;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
