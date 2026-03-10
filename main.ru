if q_index < len(QUESTIONS):
        await state.update_data(answers_yes=yes_count, current_question=q_index)
        await message.answer(f"{q_index + 1}. {QUESTIONS[q_index]}", reply_markup=get_yes_no_kb())
    else:
        # Итоги
        if yes_count <= 3:
            risk = "🟢 Низкий риск"
        elif 4 <= yes_count <= 7:
            risk = "🟡 Средний риск (плановый визит)"
        else:
            risk = "🔴 Высокий риск (СРОЧНО к врачу)"

        # Пользователю
        await message.answer(
            f"Тест завершен!\nРезультат: {yes_count} из {len(QUESTIONS)}\n\n{risk}",
            reply_markup=ReplyKeyboardRemove(),
            parse_mode="Markdown"
        )

        # Админу
        admin_card = (
            f"⚡️ Новый пациент!\n"
            f"👤 ФИО: {data['full_name']}\n"
            f"📞 Тел: {data['phone']}\n"
            f"📊 Результат: {yes_count}/11\n"
            f"📝 Риск: {risk}\n"
            f"🔗 [Профиль пользователя](tg://user?id={message.from_user.id})"
        )
        await bot.send_message(ADMIN_ID, admin_card, parse_mode="Markdown")
        await state.clear()

async def main():
    await dp.start_polling(bot)

if name == "main":
    asyncio.run(main())
