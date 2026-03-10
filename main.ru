import asyncio
from aiogram import Bot, Dispatcher, types, F
from aiogram.filters import Command
from aiogram.fsm.context import FSMContext
from aiogram.fsm.state import State, StatesGroup
from aiogram.types import ReplyKeyboardMarkup, KeyboardButton, ReplyKeyboardRemove

# --- НАСТРОЙКИ ---
TOKEN = "8395976496:AAFIWvIDNUcphfv5qOK_1OkPUuqmV0AqW9o"
ADMIN_ID = 6818025340

bot = Bot(token=TOKEN)
dp = Dispatcher()

class CardioSurvey(StatesGroup):
    name = State()
    questions = State()

QUESTIONS = [
    "1. Беспокоит ли вас давящая боль за грудиной за последнее время?",
    "2. Отдает ли боль в левую руку, плечо или челюсть в последние часы?",
    "3. Появилась ли у вас сильная одышка в состоянии покоя?",
    "4. Чувствуете ли вы перебои в работе сердца (замирание, резкие удары)?",
    "5. Появилось ли чувство страха или паники за последнее время?",
    "6. Было ли у вас резкое головокружение или потемнение в глазах?",
    "7. Заметили ли вы появление холодного липкого пота в последние часы?",
    "8. Беспокоит ли вас резкая слабость, мешающая встать, за последнее время?",
    "9. Поднималось ли артериальное давление выше вашего привычного за сутки?",
    "10. Появились ли отеки на ногах за последнее время?",
    "11. Были ли у вас приступы потери сознания в последние 24 часа?",
    "12. Беспокоит ли вас учащенное сердцебиение (более 100 ударов) в покое?",
    "13. Усиливается ли боль в груди при физической нагрузке?",
    "14. Проходит ли боль в груди после приема нитроглицерина или покоя?",
    "15. Чувствуете ли вы тяжесть в груди, мешающую сделать полный вдох?"
]

@dp.message(Command("start"))
async def cmd_start(message: types.Message, state: FSMContext):
    await state.clear()
    await message.answer(
        "<b>Добро пожаловать в Кардио-помощник.</b>\n\n"
        "Этот опрос поможет оценить состояние вашей сердечно-сосудистой системы за последнее время.\n"
        "Пожалуйста, введите ваши Имя и Фамилию:",
        parse_mode="HTML"
    )
    await state.set_state(CardioSurvey.name)

@dp.message(CardioSurvey.name)
async def process_name(message: types.Message, state: FSMContext):
    await state.update_data(user_name=message.text, q_idx=0, answers=[])
    
    kb = ReplyKeyboardMarkup(
        keyboard=[[KeyboardButton(text="Да"), KeyboardButton(text="Нет")]],
        resize_keyboard=True
    )
    await message.answer("Пожалуйста, отвечайте максимально точно на вопросы о вашем самочувствии за последние 24 часа.")
    await asyncio.sleep(0.4) # Защита от скачков
    await message.answer(QUESTIONS[0], reply_markup=kb)
    await state.set_state(CardioSurvey.questions)

@dp.message(CardioSurvey.questions)
async def handle_questions(message: types.Message, state: FSMContext):
    data = await state.get_data()
    if not data: return
    
    idx = data['q_idx']
    answers = data['answers']
    
    if message.text not in ["Да", "Нет"]:
        return

    answers.append(message.text)
    idx += 1
    await state.update_data(q_idx=idx, answers=answers)
    
    if idx < len(QUESTIONS):
        await asyncio.sleep(0.2) # Стабилизация
        await message.answer(QUESTIONS[idx])
    else:
        # Критические индексы для кардиологии (боль, одышка, липкий пот, потеря сознания)
        crit_idx = [0, 1, 2, 6, 7, 10]
        is_crit = any(answers[i] == "Да" for i in crit_idx)
        
        if is_crit:
            res = "🚨 <b>ВНИМАНИЕ: Срочно вызывайте скорую помощь (103)!</b>\n\nВаши симптомы могут указывать на прединфарктное состояние или острый коронарный синдром."
        else:
            res = "✅ Ваше состояние сейчас не оценивается как экстренное. Однако рекомендуем планово обратиться к кардиологу для обследования."
            
        await message.answer(res, parse_mode="HTML", reply_markup=ReplyKeyboardRemove())
        
        # ОТЧЕТ ТЕБЕ (САРДОРУ)
        user_info = (
            f"🫀 <b>КАРДИО-ОТЧЕТ</b>\n\n"
            f"👤 <b>ФИО:</b> {data['user_name']}\n"
            f"🆔 <b>ID:</b> <code>{message.from_user.id}</code>\n"
            f"🔗 <b>Username:</b> @{message.from_user.username if message.from_user.username else 'нет'}\n"
            f"🚨 <b>Критично:</b> {'ДА' if is_crit else 'НЕТ'}"
        )
        
        try:
            await bot.send_message(ADMIN_ID, user_info, parse_mode="HTML")
        except: pass
        await state.clear()

async def main():
    await bot.delete_webhook(drop_pending_updates=True)
    await dp.start_polling(bot)

if __name__ == "__main__":
    asyncio.run(main())
