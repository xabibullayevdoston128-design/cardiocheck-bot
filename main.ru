import logging
import asyncio
import os
from aiogram import Bot, Dispatcher, types, F
from aiogram.filters import Command
from aiogram.fsm.context import FSMContext
from aiogram.fsm.state import State, StatesGroup
from aiogram.types import ReplyKeyboardMarkup, KeyboardButton, ReplyKeyboardRemove

# Переменные окружения (настройте их в Railway)
TOKEN = os.getenv("8770551705:AAE_GYKdrx_r9ODaNNSVq1JskbqUnOyKgp0")
ADMIN_ID = os.getenv("1874217603")

bot = Bot(token=TOKEN)
dp = Dispatcher()

# Состояния опроса
class Survey(StatesGroup):
    waiting_for_agreement = State()
    waiting_for_name = State()
    waiting_for_phone = State()
    answering_questions = State()

# Список вопросов (11 штук из вашего ТЗ)
QUESTIONS = [
    "Бывает ли у вас давление выше 140/90?",
    "Бывают ли давящие боли за грудиной?",
    "Чувствуете ли вы нехватку воздуха при ходьбе?",
    "Есть ли у вас отеки ног?",
    "Курите ли вы?",
    "Есть ли у вас лишний вес?",
    "Бывают ли приступы сильного сердцебиения?",
    "Есть ли у близких родственников болезни сердца до 55 лет?",
    "Страдаете ли вы сахарным диабетом?",
    "Мало ли вы двигаетесь в течение дня?",
    "Часто ли вы просыпаетесь ночью от удушья?"
]

# Функция для определения категории риска
def get_risk_category(score):
    if 0 <= score <= 3:
        return "🟢 **Низкий риск**", "Ваши показатели в пределах нормы. Продолжайте следить за здоровьем."
    elif 4 <= score <= 7:
        return "🟡 **Средний риск**", "**Рекомендуется плановый визит к врачу-кардиологу** для профилактического осмотра."
    else:
        return "🔴 **Высокий риск**", "**ВНИМАНИЕ: Рекомендуется срочное обращение к врачу!** Высокая вероятность сердечно-сосудистых осложнений."

# Клавиатура Да/Нет
def get_yes_no_kb():
    return ReplyKeyboardMarkup(
        keyboard=[[KeyboardButton(text="Да"), KeyboardButton(text="Нет")]],
        resize_keyboard=True,
        one_time_keyboard=True
    )

@dp.message(Command("start"))
async def cmd_start(message: types.Message, state: FSMContext):
    text = (
        "❤️ **Добро пожаловать в систему кардиологического скрининга.**\n\n"
        "⚠️ **ДИСКЛЕЙМЕР:** Данный бот не является врачом, не ставит диагноз и не назначает лечение. "
        "Опрос лишь прогнозирует возможные риски на основе статистики.\n\n"
        "Вы согласны начать тест?"
    )
    kb = ReplyKeyboardMarkup(
        keyboard=[[KeyboardButton(text="Согласен, начать тест")]],
        resize_keyboard=True
    )
    await message.answer(text, reply_markup=kb, parse_mode="Markdown")
    await state.set_state(Survey.waiting_for_agreement)

@dp.message(Survey.waiting_for_agreement, F.text == "Согласен, начать тест")
async def ask_name(message: types.Message, state: FSMContext):
    await message.answer("Введите ваше ФИО:", reply_markup=ReplyKeyboardRemove())
    await state.set_state(Survey.waiting_for_name)

@dp.message(Survey.waiting_for_name)
async def ask_phone(message: types.Message, state: FSMContext):
    await state.update_data(full_name=message.text)
    kb = ReplyKeyboardMarkup(
        keyboard=[[KeyboardButton(text="📞 Отправить мой номер телефона", request_contact=True)]],
        resize_keyboard=True
    )
    await message.answer("Для регистрации нажмите кнопку ниже:", reply_markup=kb)
    await state.set_state(Survey.waiting_for_phone)

@dp.message(Survey.waiting_for_phone, F.contact)
async def start_survey(message: types.Message, state: FSMContext):
    # Сохраняем данные пользователя
    await state.update_data(
        phone=message.contact.phone_number, 
        tg_id=message.from_user.id, 
        username=f"@{message.from_user.username}" if message.from_user.username else "Нет username",
        yes_count=0, 
        current_q=0
    )
    
    await message.answer("Начинаем опрос. Используйте кнопки для ответов.", reply_markup=get_yes_no_kb())
    await message.answer(f"1. {QUESTIONS[0]}", reply_markup=get_yes_no_kb())
    await state.set_state(Survey.answering_questions)

@dp.message(Survey.answering_questions, F.text.in_(["Да", "Нет"]))
async def process_questions(message: types.Message, state: FSMContext):
    data = await state.get_data()
    current_q = data['current_q']
    yes_count = data['yes_count']
    
    if message.text == "Да":
        yes_count += 1
    
    current_q += 1
    
    if current_q < len(QUESTIONS):
        await state.update_data(current_q=current_q, yes_count=yes_count)
        await message.answer(f"{current_q + 1}. {QUESTIONS[current_q]}", reply_markup=get_yes_no_kb())
    else:
        # Этап 4: Обработка результата
        category_title, recommendation = get_risk_category(yes_count)
        
        # Ответ пользователю
        await message.answer(
            f"**Тест завершен.**\n\nРезультат: {category_title}\n\n{recommendation}",
            reply_markup=ReplyKeyboardRemove(),
            parse_mode="Markdown"
        )
        
        # Этап 5: Уведомление администратора
        admin_text = (
            f"📥 **НОВАЯ ЗАЯВКА**\n"
            f"👤 **ФИО:** {data['full_name']}\n"
            f"📞 **Телефон:** [{data['phone']}](tel:{data['phone']})\n"
            f"🆔 **ID:** `{data['tg_id']}`\n"
            f"🔗 **Профиль:** {data['username']}\n\n"
            f"📊 **Результат:** {yes_count} из 11\n"
            f"⚠️ **Категория:** {category_title}"
        )
        
        if ADMIN_ID:
            try:
                await bot.send_message(ADMIN_ID, admin_text, parse_mode="Markdown")
            except Exception as e:
                logging.error(f"Ошибка отправки админу: {e}")
            
        await state.clear()

async def main():
    await dp.start_polling(bot)

if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    asyncio.run(main())
